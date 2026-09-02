import Vision
import UIKit
import CryptoKit
import os.log

final class AerthysReferenceMatcher: @unchecked Sendable {

    private static let featurePrintRevision = VNGenerateImageFeaturePrintRequestRevision1
    private static let manifestResource = "AerthysReferences"

    private let queue = DispatchQueue(label: "com.example.aerthys.matcher", qos: .userInitiated)
    private let log = Logger(subsystem: "com.example.aerthys", category: "AerthysReferenceMatcher")

    private struct Reference { let label: AerthysReferenceClass; let print: VNFeaturePrintObservation }

    private var references: [Reference] = []
    private var loadFailure: AerthysMatcherError?
    private var isLoaded = false

    func warmUp() {
        queue.async { [weak self] in _ = try? self?.loadReferencesIfNeeded() }
    }

    func match(_ image: UIImage) async throws -> AerthysMatchOutcome {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: AerthysMatcherError.deallocated); return
                }
                do {
                    continuation.resume(returning: try self.matchSynchronously(image))
                } catch let error as AerthysMatcherError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: AerthysMatcherError.visionFailed(error.localizedDescription))
                }
            }
        }
    }

    private func matchSynchronously(_ image: UIImage) throws -> AerthysMatchOutcome {
        try loadReferencesIfNeeded()

        let preprocessed = try ImagePreprocessor.preprocess(image)
        guard let livePrint = try featurePrint(cgImage: preprocessed.cgImage,
                                               orientation: preprocessed.orientation) else {
            throw AerthysMatcherError.featurePrintFailed
        }

        let distances: [(label: AerthysReferenceClass, distance: Double)] = references.map { ref in
            var d: Float = 0
            try? livePrint.computeDistance(&d, to: ref.print)
            return (ref.label, Double(d))
        }
        guard !distances.isEmpty else { throw AerthysMatcherError.noReferencePrints }

        let outcome = AerthysMatchDecision.decide(distances: distances)
        #if DEBUG
        switch outcome {
        case .recognized(let cls, let score):
            log.debug("Aerthys → \(cls.rawValue, privacy: .public) (score \(String(format: "%.2f", score), privacy: .public))")
        case .rejected(let score):
            log.debug("Aerthys → RECHAZADO (score \(String(format: "%.2f", score), privacy: .public))")
        }
        #endif
        return outcome
    }

    private func featurePrint(cgImage: CGImage,
                              orientation: CGImagePropertyOrientation = .up) throws -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = Self.featurePrintRevision
        request.imageCropAndScaleOption = .centerCrop
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try handler.perform([request])
        return request.results?.first as? VNFeaturePrintObservation
    }

    private func loadReferencesIfNeeded() throws {
        if isLoaded { return }
        if let loadFailure { throw loadFailure }

        do {
            let manifest = try loadManifest()

            if let cached = loadCachedPrints(manifestFingerprint: manifest.fingerprint),
               cached.count == manifest.entries.count {
                references = cached
                isLoaded = true
                log.debug("Aerthys references loaded from disk cache (\(cached.count, privacy: .public))")
                return
            }

            var built: [Reference] = []
            for entry in manifest.entries {
                guard let url = Bundle.main.url(forResource: entry.fileStem, withExtension: "jpg"),
                      let image = UIImage(contentsOfFile: url.path),
                      let cgImage = image.cgImage,
                      let print = try? featurePrint(cgImage: cgImage) else {
                    log.error("Aerthys reference unusable: \(entry.file, privacy: .public)")
                    continue
                }
                built.append(Reference(label: entry.label, print: print))
            }

            guard !built.isEmpty else {
                loadFailure = .noReferencePrints
                throw AerthysMatcherError.noReferencePrints
            }
            if built.count < manifest.entries.count {
                log.error("Aerthys: \(manifest.entries.count - built.count, privacy: .public) reference(s) failed to load")
            }

            references = built
            isLoaded = true
            saveCachedPrints(built, manifestFingerprint: manifest.fingerprint)
        } catch let error as AerthysMatcherError {
            loadFailure = error
            throw error
        } catch {
            loadFailure = .referencesNotFound
            throw AerthysMatcherError.referencesNotFound
        }
    }

    private struct Manifest {
        struct Entry { let file: String; let label: AerthysReferenceClass; var fileStem: String { (file as NSString).deletingPathExtension } }
        let entries: [Entry]
        let fingerprint: String
    }

    private func loadManifest() throws -> Manifest {
        guard let url = Bundle.main.url(forResource: Self.manifestResource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            throw AerthysMatcherError.referencesNotFound
        }
        struct RawEntry: Decodable { let file: String; let label: String }
        struct Raw: Decodable { let references: [RawEntry]; let featurePrintRevision: Int? }
        guard let raw = try? JSONDecoder().decode(Raw.self, from: data), !raw.references.isEmpty else {
            throw AerthysMatcherError.referencesNotFound
        }
        let entries = raw.references.compactMap { e -> Manifest.Entry? in
            guard let label = AerthysReferenceClass(rawValue: e.label) else { return nil }
            return Manifest.Entry(file: e.file, label: label)
        }
        guard !entries.isEmpty else { throw AerthysMatcherError.referencesNotFound }
        let digest = SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
        return Manifest(entries: entries, fingerprint: "r\(Self.featurePrintRevision)-\(digest)")
    }

    private var cacheURL: URL? {
        try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                     appropriateFor: nil, create: true)
            .appendingPathComponent("AerthysRefPrints.archive")
    }

    private func loadCachedPrints(manifestFingerprint: String) -> [Reference]? {
        guard let url = cacheURL, let data = try? Data(contentsOf: url) else { return nil }
        guard let root = try? NSKeyedUnarchiver.unarchivedObject(
            ofClasses: [NSDictionary.self, NSArray.self, NSString.self, VNFeaturePrintObservation.self],
            from: data) as? [String: Any],
            root["fingerprint"] as? String == manifestFingerprint,
            let labels = root["labels"] as? [String],
            let prints = root["prints"] as? [VNFeaturePrintObservation],
            labels.count == prints.count
        else { return nil }
        var refs: [Reference] = []
        for (labelString, print) in zip(labels, prints) {
            guard let label = AerthysReferenceClass(rawValue: labelString) else { return nil }
            refs.append(Reference(label: label, print: print))
        }
        return refs
    }

    private func saveCachedPrints(_ refs: [Reference], manifestFingerprint: String) {
        guard let url = cacheURL else { return }
        let root: [String: Any] = [
            "fingerprint": manifestFingerprint,
            "labels": refs.map { $0.label.rawValue },
            "prints": refs.map { $0.print },
        ]
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: root,
                                                           requiringSecureCoding: true) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
