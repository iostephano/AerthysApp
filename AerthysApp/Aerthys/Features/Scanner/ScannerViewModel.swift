import Foundation
import UIKit
import os.log

@MainActor
final class ScannerViewModel: ObservableObject {
    @Published private(set) var state: AnalysisState = .camera
    @Published private(set) var statusText: String = ScannerViewModel.idleText
    @Published var isInfoPresented = false

    @Published private(set) var capturedImage: UIImage?

    @Published private(set) var assessment: AirQualityAssessment?

    let cameraService = CameraService()
    private let referenceMatcher = AerthysReferenceMatcher()

    private var matchOutcome: AerthysMatchOutcome?
    private var matchError: AerthysMatcherError?

    var isBusy: Bool { state != .camera }

    private static let idleText = "Centra la muestra dentro del área de análisis"
    private static let analyzingTexts = [
        "Analizando pigmentación…",
        "Analizando estructura…",
        "Comparando patrones…",
    ]

    private let log = Logger(subsystem: "com.example.aerthys", category: "ScannerViewModel")
    private var scanTask: Task<Void, Never>?

    func onAppear() async {
        referenceMatcher.warmUp()
        await cameraService.requestAccessAndStart()
    }

    func onDisappear() {
        cancelScan()
        cameraService.stopSession()
    }

    func toggleTorch() {
        cameraService.toggleTorch()
    }

    func handleScenePhaseChange(isActive: Bool) {
        guard !isActive, isBusy else { return }
        cancelScan()
        resetToCamera()
    }

    func startScan() {
        guard !isBusy else { return }
        capturedImage = nil
        assessment = nil
        matchOutcome = nil
        matchError = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        scanTask = Task { [weak self] in
            await self?.runScanSequence()
        }
    }

    func resetToCamera() {
        capturedImage = nil
        assessment = nil
        matchOutcome = nil
        matchError = nil
        state = .camera
        statusText = Self.idleText
    }

    private func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
    }

    private func runScanSequence() async {
        state = .detecting
        statusText = "Buscando muestra…"
        guard await sleepUnlessCancelled(seconds: 0.65) else { return }

        statusText = "Muestra localizada"
        guard await sleepUnlessCancelled(seconds: 0.4) else { return }

        state = .scanning
        statusText = "Escaneando muestra…"
        guard await sleepUnlessCancelled(seconds: 0.9) else { return }

        let image = await capturePhotoAsync()
        guard !Task.isCancelled else { return }
        capturedImage = image

        guard let image else {
            log.error("Scan finished without a captured image.")
            resetToCamera()
            scanTask = nil
            return
        }

        state = .analyzing
        async let matchTask: Void = performMatch(image)
        async let textSequenceTask: Void = runAnalyzingTextSequence()
        _ = await (matchTask, textSequenceTask)
        guard !Task.isCancelled else { return }

        switch matchOutcome {
        case .recognized(let referenceClass, _):
            let result = AirQualityAssessment(referenceClass)
            assessment = result
            triggerResultHaptic(for: result)
            state = .result

        case .rejected:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            state = .noLichen

        case .none:
            resetToCamera()
        }
        scanTask = nil
    }

    private func runAnalyzingTextSequence() async {
        for text in Self.analyzingTexts {
            guard !Task.isCancelled else { return }
            statusText = text
            guard await sleepUnlessCancelled(seconds: 0.6) else { return }
        }
    }

    private func performMatch(_ image: UIImage) async {
        do {
            matchOutcome = try await referenceMatcher.match(image)
            matchError = nil
        } catch let error as AerthysMatcherError {
            matchOutcome = nil
            matchError = error
            log.error("Aerthys match failed: \(String(describing: error), privacy: .public)")
        } catch {
            matchOutcome = nil
            matchError = .visionFailed(error.localizedDescription)
            log.error("Aerthys match failed unexpectedly: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func triggerResultHaptic(for assessment: AirQualityAssessment) {
        let generator = UINotificationFeedbackGenerator()
        switch assessment {
        case .low:
            generator.notificationOccurred(.success)
        case .moderate, .high:
            generator.notificationOccurred(.warning)
        }
    }

    private func sleepUnlessCancelled(seconds: Double) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        } catch {
            return false
        }
        return !Task.isCancelled
    }

    private func capturePhotoAsync() async -> UIImage? {
        await withCheckedContinuation { continuation in
            cameraService.capturePhoto { image in
                continuation.resume(returning: image)
            }
        }
    }
}
