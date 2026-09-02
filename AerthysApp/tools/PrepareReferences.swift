#!/usr/bin/swift

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: PrepareReferences <AerthysV2Root> [cropFraction] [outSize]")
    exit(1)
}
let root = URL(fileURLWithPath: args[1])
let cropFraction = args.count > 2 ? (Double(args[2]) ?? 0.82) : 0.82
let outSize = args.count > 3 ? (Int(args[3]) ?? 640) : 640
let fm = FileManager.default

let refRoot = root.appendingPathComponent("References")
let calRoot = root.appendingPathComponent("Calibration")
let outRoot = root.appendingPathComponent("Output/BundleReferences")
let outCal = root.appendingPathComponent("Output/CalibrationPrepared")

func loadImage(_ url: URL) -> CGImage? {
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
    let x = (w - side) / 2, y = (h - side) / 2
    return img.cropping(to: CGRect(x: x, y: y, width: side, height: side))
}

func resized(_ img: CGImage, to size: Int) -> CGImage? {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                              bytesPerRow: 0, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.interpolationQuality = .high
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: size, height: size))
    return ctx.makeImage()
}

func writeJPEG(_ img: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, img, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
    CGImageDestinationFinalize(dest)
}

struct ManifestEntry: Codable { let file: String; let label: String; let sourceFile: String }
var manifest: [ManifestEntry] = []

func process(classDir: URL, label: String, into destDir: URL, index: inout Int) -> Int {
    let files = ((try? fm.contentsOfDirectory(at: classDir, includingPropertiesForKeys: nil)) ?? [])
        .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)
    var n = 0
    for f in files {
        guard let img = loadImage(f),
              let cropped = centerCropSquare(img, fraction: cropFraction),
              let out = resized(cropped, to: outSize) else {
            print("  ! could not process \(f.lastPathComponent)"); continue
        }
        index += 1
        let name = String(format: "%@_%03d.jpg", label, index)
        writeJPEG(out, to: destDir.appendingPathComponent(name))
        manifest.append(ManifestEntry(file: name, label: label, sourceFile: f.lastPathComponent))
        n += 1
    }
    return n
}

print("=== References (cropFraction \(cropFraction), \(outSize)px) ===")
var total = 0
for label in ["low", "moderate", "high"] {
    var idx = 0
    let n = process(classDir: refRoot.appendingPathComponent(label), label: label,
                    into: outRoot.appendingPathComponent(label), index: &idx)
    print("  \(label): \(n) prepared")
    total += n
    if n == 0 { print("  (empty — waiting for user photos)") }
    if n > 0 && n < 25 { print("  WARNING: <25 references for \(label); spec asks 25–40.") }
}

if !manifest.isEmpty {
    let data = try JSONEncoder().encode(["references": manifest])
    try data.write(to: outRoot.appendingPathComponent("manifest.json"))
    print("  wrote manifest.json (\(manifest.count) entries)")
}

let otherDir = calRoot.appendingPathComponent("other")
if fm.fileExists(atPath: otherDir.path) {
    var idx = 0
    var calManifest: [ManifestEntry] = []
    let files = ((try? fm.contentsOfDirectory(at: otherDir, includingPropertiesForKeys: nil)) ?? [])
        .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
    try? fm.createDirectory(at: outCal, withIntermediateDirectories: true)
    for f in files {
        guard let img = loadImage(f), let c = centerCropSquare(img, fraction: cropFraction),
              let out = resized(c, to: outSize) else { continue }
        idx += 1
        let name = String(format: "other_%03d.jpg", idx)
        writeJPEG(out, to: outCal.appendingPathComponent(name))
        calManifest.append(ManifestEntry(file: name, label: "other", sourceFile: f.lastPathComponent))
    }
    print("\n=== Calibration/other: \(idx) prepared (reject-set, NOT training) ===")
}

print("\nTotal references: \(total)")
print(total == 0
      ? "\nNo references yet. Place photos in Training/AerthysV2/References/{low,moderate,high}/ and re-run."
      : "\nNext: swift Training/AerthysV2/Tools/CalibrateMatcher.swift \(root.path)")
