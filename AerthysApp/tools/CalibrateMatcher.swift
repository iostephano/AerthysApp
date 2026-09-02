#!/usr/bin/swift

import Foundation
import Vision
import CoreGraphics
import ImageIO

let FEATURE_PRINT_REVISION = VNGenerateImageFeaturePrintRequestRevision1

let args = CommandLine.arguments
guard args.count >= 2 else { print("Usage: CalibrateMatcher <AerthysV2Root> [cropFraction]"); exit(1) }
let root = URL(fileURLWithPath: args[1])
let cropFraction = args.count > 2 ? (Double(args[2]) ?? 0.82) : 0.82
let bundleRefs = root.appendingPathComponent("Output/BundleReferences")
let otherRaw = root.appendingPathComponent("Calibration/other")
let otherPrepared = root.appendingPathComponent("Output/CalibrationPrepared")
let otherPreviousPrepared = root.appendingPathComponent("Output/CalibrationPreviousPrepared")
let reportURL = root.appendingPathComponent("Reports/calibration.md")
let fm = FileManager.default
let classes = ["low", "moderate", "high"]

func loadOriented(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                 kCGImageSourceCreateThumbnailWithTransform: true,
                                 kCGImageSourceThumbnailMaxPixelSize: 4096]
    return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
        ?? CGImageSourceCreateImageAtIndex(src, 0, nil)
}
func centerCropSquare(_ img: CGImage, fraction: Double) -> CGImage? {
    let w = img.width, h = img.height
    let side = Int((Double(min(w, h)) * fraction).rounded())
    guard side > 0 else { return nil }
    return img.cropping(to: CGRect(x: (w - side) / 2, y: (h - side) / 2, width: side, height: side))
}
func loadCGAlreadyCropped(_ url: URL) -> CGImage? {
    guard let s = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(s, 0, nil)
}
func writeJPEG(_ img: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, img, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
    CGImageDestinationFinalize(dest)
}

func featurePrint(_ img: CGImage) -> VNFeaturePrintObservation? {
    let req = VNGenerateImageFeaturePrintRequest()
    req.revision = FEATURE_PRINT_REVISION
    req.imageCropAndScaleOption = .centerCrop
    let handler = VNImageRequestHandler(cgImage: img, options: [:])
    do { try handler.perform([req]) } catch { return nil }
    return req.results?.first as? VNFeaturePrintObservation
}
func distance(_ a: VNFeaturePrintObservation, _ b: VNFeaturePrintObservation) -> Double {
    var d: Float = 0
    do { try a.computeDistance(&d, to: b) } catch { return .infinity }
    return Double(d)
}

struct Ref { let label: String; let file: String; let print: VNFeaturePrintObservation }

var refs: [Ref] = []
for label in classes {
    let dir = bundleRefs.appendingPathComponent(label)
    let files = ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
        .filter { $0.pathExtension.lowercased() == "jpg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    for f in files {
        guard let img = loadCGAlreadyCropped(f), let fp = featurePrint(img) else { print("! print failed \(f.lastPathComponent)"); continue }
        refs.append(Ref(label: label, file: f.lastPathComponent, print: fp))
    }
}
guard !refs.isEmpty else {
    print("No prepared references. Run PrepareReferences.swift first (after placing photos).")
    exit(1)
}
let counts = Dictionary(grouping: refs, by: \.label).mapValues(\.count)
print("Loaded active references: \(counts)  (total \(refs.count))")

struct OtherPrint { let file: String; let pool: String; let print: VNFeaturePrintObservation }
var otherAll: [OtherPrint] = []

try? fm.createDirectory(at: otherPrepared, withIntermediateDirectories: true)
for old in (try? fm.contentsOfDirectory(at: otherPrepared, includingPropertiesForKeys: nil)) ?? [] { try? fm.removeItem(at: old) }
let otherFiles = ((try? fm.contentsOfDirectory(at: otherRaw, includingPropertiesForKeys: nil)) ?? [])
    .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
    .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
for (i, f) in otherFiles.enumerated() {
    guard let raw = loadOriented(f), let cropped = centerCropSquare(raw, fraction: cropFraction) else {
        print("! could not prepare \(f.lastPathComponent)"); continue
    }
    let name = String(format: "other_white_%03d.jpg", i + 1)
    writeJPEG(cropped, to: otherPrepared.appendingPathComponent(name))
    guard let fp = featurePrint(cropped) else { print("! print failed \(name)"); continue }
    otherAll.append(OtherPrint(file: name, pool: "white", print: fp))
}

if fm.fileExists(atPath: otherPreviousPrepared.path) {
    let prevFiles = ((try? fm.contentsOfDirectory(at: otherPreviousPrepared, includingPropertiesForKeys: nil)) ?? [])
        .filter { $0.pathExtension.lowercased() == "jpg" }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    for f in prevFiles {
        guard let img = loadCGAlreadyCropped(f), let fp = featurePrint(img) else { continue }
        otherAll.append(OtherPrint(file: f.lastPathComponent, pool: "previous", print: fp))
    }
}
let nWhite = otherAll.filter { $0.pool == "white" }.count
let nPrev = otherAll.filter { $0.pool == "previous" }.count
print("Loaded 'other' reject-set: white=\(nWhite) (raw \(otherFiles.count))  previous=\(nPrev)  total=\(otherAll.count)")

let otherPrints: [(file: String, print: VNFeaturePrintObservation)] = otherAll.map { ($0.file, $0.print) }

func sortedDistances(from p: VNFeaturePrintObservation, to pool: [Ref]) -> [(label: String, d: Double)] {
    pool.map { ($0.label, distance(p, $0.print)) }.sorted { $0.d < $1.d }
}
func score(for p: VNFeaturePrintObservation, label: String, pool: [Ref], bestN: Int) -> Double {
    let ds = pool.filter { $0.label == label }.map { distance(p, $0.print) }.sorted()
    guard !ds.isEmpty else { return .infinity }
    let n = min(bestN, ds.count)
    return ds.prefix(n).reduce(0, +) / Double(n)
}
func knnVote(_ p: VNFeaturePrintObservation, _ pool: [Ref], _ k: Int) -> String {
    let top = sortedDistances(from: p, to: pool).prefix(k)
    var counts: [String: Int] = [:]
    for t in top { counts[t.label, default: 0] += 1 }
    return classes.max { (counts[$0] ?? 0) < (counts[$1] ?? 0) }!
}
func meanBestClass(_ p: VNFeaturePrintObservation, _ pool: [Ref], _ n: Int) -> (label: String, score: Double) {
    classes.map { ($0, score(for: p, label: $0, pool: pool, bestN: n)) }.min { $0.1 < $1.1 }!
}

print("\n=== Separability (leave-one-out, distance to nearest same vs other class) ===")
var sepLines: [String] = []
for label in classes {
    var sameNN: [Double] = [], otherNN: [Double] = []
    for r in refs.filter({ $0.label == label }) {
        let others = refs.filter { $0.file != r.file }
        let sorted = sortedDistances(from: r.print, to: others)
        if let s = sorted.first(where: { $0.label == label })?.d { sameNN.append(s) }
        if let o = sorted.first(where: { $0.label != label })?.d { otherNN.append(o) }
    }
    func stat(_ x: [Double]) -> String {
        guard !x.isEmpty else { return "n/a" }
        let s = x.sorted(); return String(format: "min %.3f  med %.3f  max %.3f", s.first!, s[s.count / 2], s.last!)
    }
    let line = "\(label): same-class NN [\(stat(sameNN))] | other-class NN [\(stat(otherNN))]"
    print("  " + line); sepLines.append(line)
}

print("\n=== Leave-one-out classification accuracy by strategy ===")
func classifyKNN(_ k: Int) -> (VNFeaturePrintObservation, [Ref]) -> String { { p, pool in knnVote(p, pool, k) } }
func classifyMeanBest(_ n: Int) -> (VNFeaturePrintObservation, [Ref]) -> String { { p, pool in meanBestClass(p, pool, n).label } }
let strategies: [(String, (VNFeaturePrintObservation, [Ref]) -> String)] = [
    ("1-NN", classifyKNN(1)), ("3-NN vote", classifyKNN(3)), ("5-NN vote", classifyKNN(5)),
    ("mean-best-3", classifyMeanBest(3)), ("mean-best-5", classifyMeanBest(5)),
]
func looResults(_ classify: (VNFeaturePrintObservation, [Ref]) -> String) -> (acc: Double, perClass: [String: Double], cm: [String: [String: Int]]) {
    var cm: [String: [String: Int]] = [:]
    var correct = 0
    for r in refs {
        let pred = classify(r.print, refs.filter { $0.file != r.file })
        cm[r.label, default: [:]][pred, default: 0] += 1
        if pred == r.label { correct += 1 }
    }
    var perClass: [String: Double] = [:]
    for c in classes {
        let total = refs.filter { $0.label == c }.count
        let right = cm[c]?[c] ?? 0
        perClass[c] = total == 0 ? 0 : Double(right) / Double(total)
    }
    return (Double(correct) / Double(refs.count), perClass, cm)
}
var stratLines: [String] = []
var bestName = ""; var bestAcc = -1.0; var bestResult: (acc: Double, perClass: [String: Double], cm: [String: [String: Int]])!
for (name, fn) in strategies {
    let r = looResults(fn)
    let line = String(format: "%-12@ %.1f%%", name as NSString, r.acc * 100)
    print("  " + line); stratLines.append(line)
    if r.acc > bestAcc { bestAcc = r.acc; bestName = name; bestResult = r }
}
print("\n  Best: \(bestName) (\(String(format: "%.1f%%", bestAcc * 100)))")
print("  Confusion matrix (\(bestName), row=actual col=predicted):")
var header = "            "; for c in classes { header += c.padding(toLength: 10, withPad: " ", startingAt: 0) }
print("  " + header)
for a in classes {
    var line = "  " + a.padding(toLength: 12, withPad: " ", startingAt: 0)
    for c in classes { line += String(bestResult.cm[a]?[c] ?? 0).padding(toLength: 10, withPad: " ", startingAt: 0) }
    print(line)
}
print("  Per-class accuracy: " + classes.map { String(format: "%@=%.1f%%", $0 as NSString, (bestResult.perClass[$0] ?? 0) * 100) }.joined(separator: "  "))

print("\n=== Threshold sweep (score = mean distance to best-3 refs of the predicted class) ===")
let refScores: [Double] = refs.map { r in score(for: r.print, label: r.label, pool: refs.filter { $0.file != r.file }, bestN: 3) }
let otherScores: [Double] = otherPrints.map { meanBestClass($0.print, refs, 3).score }
let otherScoreByPool: [String: [Double]] = Dictionary(grouping: otherAll, by: \.pool)
    .mapValues { $0.map { meanBestClass($0.print, refs, 3).score } }
func rejectRate(_ scores: [Double], at threshold: Double) -> Double {
    scores.isEmpty ? .nan : Double(scores.filter { $0 > threshold }.count) / Double(scores.count)
}

let allRefSorted = refScores.sorted()
let maxRef = allRefSorted.last ?? 0
let p95 = allRefSorted.isEmpty ? 0 : allRefSorted[Int(Double(allRefSorted.count - 1) * 0.95)]
let otherSorted = otherScores.sorted()
let minOther = otherSorted.first ?? .infinity
print(String(format: "  reference score:  min %.3f  med %.3f  p95 %.3f  max %.3f", allRefSorted.first ?? 0, allRefSorted[allRefSorted.count / 2], p95, maxRef))
if !otherScores.isEmpty {
    print(String(format: "  other/reject score: min %.3f  med %.3f  max %.3f  (n=%d)", otherSorted.first!, otherSorted[otherSorted.count / 2], otherSorted.last!, otherScores.count))
} else {
    print("  other/reject score: (Calibration/other is empty)")
}

var sweepLines: [String] = []
let lo = allRefSorted.first ?? 0.0, hi = max(otherSorted.last ?? 0, maxRef)
let stepCount = 24
let step = stepCount > 0 ? (hi - lo) / Double(stepCount) : 0
print("\n  thr     ref coverage   other rejected")
var t = lo
for _ in 0...stepCount {
    let cov = refScores.isEmpty ? 0 : Double(refScores.filter { $0 <= t }.count) / Double(refScores.count)
    let rej = otherScores.isEmpty ? Double.nan : Double(otherScores.filter { $0 > t }.count) / Double(otherScores.count)
    let line = String(format: "  %.3f    %5.1f%%        %@", t, cov * 100, rej.isNaN ? "n/a" : String(format: "%5.1f%%", rej * 100))
    print(line); sweepLines.append(line)
    t += step
}

let hasCleanGap = !otherScores.isEmpty && maxRef < minOther
let recommended: Double = otherScores.isEmpty ? p95 : (hasCleanGap ? (maxRef + (minOther - maxRef) * 0.5) : p95)
let margin = otherScores.isEmpty ? Double.nan : (minOther - maxRef)
let refCoverageAtT = refScores.isEmpty ? 0 : Double(refScores.filter { $0 <= recommended }.count) / Double(refScores.count)
let otherRejectedAtT = otherScores.isEmpty ? Double.nan : Double(otherScores.filter { $0 > recommended }.count) / Double(otherScores.count)

print(String(format: "\n  RECOMMENDED threshold ≈ %.3f  (accept if score ≤ threshold, else RECHAZO)", recommended))
print("  clean gap: \(hasCleanGap ? "yes" : "no")" + (otherScores.isEmpty ? "" : String(format: "   margin (min other − max ref) = %.3f", margin)))
print(String(format: "  at this threshold: ref coverage %.1f%%   other rejected (all) %@", refCoverageAtT * 100, otherRejectedAtT.isNaN ? "n/a" : String(format: "%.1f%%", otherRejectedAtT * 100)))
for pool in ["white", "previous"] {
    guard let s = otherScoreByPool[pool], !s.isEmpty else { continue }
    let sorted = s.sorted()
    print(String(format: "    pool '%@' (n=%d): min %.3f  rejected@thr %.1f%%", pool as NSString, s.count, sorted.first!, rejectRate(s, at: recommended) * 100))
}

let md = """
# Aerthys — Calibration Report

_Generado: \(ISO8601DateFormatter().string(from: Date()))_
_Feature print revision: \(FEATURE_PRINT_REVISION) · cropFraction \(cropFraction)_
_Referencias activas: \(counts) (total \(refs.count)) · 'other': \(otherPrints.count) de \(otherFiles.count) archivos crudos_

## Separabilidad (leave-one-out)
\(sepLines.map { "- \($0)" }.joined(separator: "\n"))

## Estrategias (accuracy leave-one-out)
\(stratLines.map { "- \($0)" }.joined(separator: "\n"))

**Mejor estrategia:** \(bestName) (\(String(format: "%.1f%%", bestAcc * 100)))

**Matriz de confusión (\(bestName), fila=real, col=predicho):**
```
\(header)
\(classes.map { a in a.padding(toLength: 12, withPad: " ", startingAt: 0) + classes.map { String(bestResult.cm[a]?[$0] ?? 0).padding(toLength: 10, withPad: " ", startingAt: 0) }.joined() }.joined(separator: "\n"))
```

**Accuracy final por clase:** \(classes.map { String(format: "%@ = %.1f%%", $0 as NSString, (bestResult.perClass[$0] ?? 0) * 100) }.joined(separator: "  ·  "))

## Umbral de rechazo
- score de referencia: max = \(String(format: "%.3f", maxRef)), p95 = \(String(format: "%.3f", p95))
- score de 'other' (todos): \(otherScores.isEmpty ? "sin datos" : "min = \(String(format: "%.3f", minOther))")
- margen (min other − max ref): \(margin.isNaN ? "n/a" : String(format: "%.3f", margin))
- **umbral recomendado ≈ \(String(format: "%.3f", recommended))**
- a ese umbral: cobertura de referencias \(String(format: "%.1f%%", refCoverageAtT * 100)) · 'other' rechazadas (todos) \(otherRejectedAtT.isNaN ? "n/a" : String(format: "%.1f%%", otherRejectedAtT * 100))

### Rechazo por pool de 'other'
\(["white", "previous"].compactMap { pool -> String? in
    guard let s = otherScoreByPool[pool], !s.isEmpty else { return nil }
    let sorted = s.sorted()
    return String(format: "- **%@** (n=%d): min score %.3f · rechazadas @ umbral %.1f%%", pool as NSString, s.count, sorted.first!, rejectRate(s, at: recommended) * 100)
}.joined(separator: "\n"))

## Config sugerida para la app
```
strategy     = \(bestName)
rejectScore  = media de las 3 distancias mínimas a la clase votada
threshold    = \(String(format: "%.3f", recommended))
revision     = \(FEATURE_PRINT_REVISION)
cropFraction = \(cropFraction)
```

## Barrido completo
```
thr     ref coverage   other rejected
\(sweepLines.joined(separator: "\n"))
```
"""
try? md.write(to: reportURL, atomically: true, encoding: .utf8)
print("\nWrote \(reportURL.path)")
