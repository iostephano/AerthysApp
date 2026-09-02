# Aerthys — implementation notes

Architecture reference for the app. Not the README.

## Recognition pipeline

```
Camera (AVFoundation, AVCapturePhotoOutput, back wide-angle camera)
  → ROI (square center crop)
  → ImagePreprocessor (square center crop + orientation)
  → Vision Feature Print (VNGenerateImageFeaturePrintRequest)
  → similarity comparison (VNFeaturePrintObservation.computeDistance vs bundled references)
  → 5-NN vote → class
  → rejection threshold on the reject score
  → LOW / MODERATE / HIGH   or   REJECTED
  → UI (ResultView, or RejectionOverlayView)
```

Runs entirely offline; no networking.

## ROI

- `AnalysisRegion.cropFraction = 0.82`.
- `AnalysisRegion` is the single source of truth. The on-screen reticle
  (`AnalysisFrameView`) draws its side from
  `AnalysisRegion.frameSide(forContainerWidth:)` = `containerWidth * cropFraction`,
  and `ImagePreprocessor` crops `min(width, height) * cropFraction`. The
  visible frame and the real crop always move together — `cropFraction` is
  the only knob.
- Geometry: the camera preview uses `.resizeAspectFill`; portrait-locked,
  iPhone-only. The 4:3 sensor photo is scaled so its width matches the
  screen width (top/bottom cropped, never the sides), so the captured
  photo's full width equals the container width and
  `cropFraction * shorterSide` on the photo equals
  `cropFraction * containerWidth` on screen.
- `0.82` is wide on purpose: Aerthys recognizes the whole sample
  (specimen + container + controlled context), so the crop keeps a margin
  of context and lets the user move in closer to the container.
- `ImagePreprocessor` runs no object detection or segmentation — just the
  centered square crop. It crops the raw (un-rotated) pixel buffer before
  applying orientation, which is safe because a centered square crop is
  unchanged by any 90°-multiple rotation about the same center; it passes
  the `CGImagePropertyOrientation` to Vision separately
  (`AVCapturePhotoOutput` often returns portrait photos tagged as rotated
  rather than pre-rotated).

## Reference matching

- 49 bundled references — LOW 18, MODERATE 18, HIGH 13.
  `Aerthys/Resources/AerthysReferences/` + `AerthysReferences.json`.
- `VNGenerateImageFeaturePrintRequest` **Revision 1** (`.centerCrop`),
  pinned. It must match the revision used by
  `tools/CalibrateMatcher.swift`. Revision 1 is available iOS 13+; the app
  targets iOS 16.
- 5-NN vote (`AerthysMatchDecision.voteK = 5`). The vote uses a fixed
  class order (`AerthysReferenceClass.allCases` = low, moderate, high)
  with "last wins" on ties — this matches `CalibrateMatcher.swift` so the
  app reproduces the calibration numbers, and it resolves a tie toward the
  more cautious (higher) class.
- `rejectScore` = mean of the N smallest distances to the voted class,
  `AerthysMatchDecision.rejectScoreNearest = 3`.
- `AerthysMatchDecision.calibratedThreshold = 18.379`. Accept iff
  `rejectScore <= threshold`, otherwise REJECTED.
- `AerthysReferenceMatcher` is the sole owner of the Vision feature-print
  pipeline; no Vision types leak out of it. It is `@unchecked Sendable`
  because every mutable stored property is only ever touched from its
  serial `queue` (manual synchronization).
- `AirQualityAssessment(_ AerthysReferenceClass)` maps the recognized
  class directly: `low → BAJO`, `moderate → MODERADO`, `high → ALTO`.

## Matcher cache

- `AerthysReferenceMatcher.warmUp()` is fire-and-forget, called when the
  scanner appears. It builds (or loads) the reference feature prints once,
  ahead of the first scan.
- The reference feature prints are computed on-device from the bundled
  JPEGs (so the Vision revision always matches), once per launch, then
  held in an in-memory cache for the process lifetime. Per-scan cost is
  then one feature print of the live image plus N `computeDistance` calls.
- Best-effort disk cache: after first computation the prints are archived
  with `NSKeyedArchiver` (secure coding) to
  `Caches/AerthysRefPrints.archive`.
- Invalidation: the cache stores a fingerprint `r<revision>-<sha256[:8]>`
  built from the feature-print revision and a SHA-256 of
  `AerthysReferences.json`. On load, the fingerprint and the entry count
  must match, otherwise the prints are recomputed and the cache rewritten.
  Every disk-cache path is best-effort — any failure falls back to
  in-memory computation.

## Scanner state flow

```
.camera → .detecting → .scanning → .analyzing → .result
                                             ↘ .noLichen
```

- `.detecting` and `.scanning` are visual, timed states only — no computer
  vision runs in them. The real photo capture happens at the end of
  `.scanning` (`AVCapturePhotoOutput`).
- `.analyzing` runs the matcher in the background while a short animated
  text sequence plays for a minimum comprehensible duration.
- `.noLichen` is the single non-fatal off-ramp: reached when the matcher
  returns `.rejected`. It shows `RejectionOverlayView` over the live
  camera (never `ResultView`) and its button returns to `.camera` without
  restarting the capture session. A matcher error (not a rejection) also
  returns to `.camera`.
- Leaving the foreground mid-scan cancels the scan and returns to `.camera`.
- `ScanLineView` is decorative, shown only while `.scanning`; it reads no
  camera pixels. Its line travels the full inner height of the reticle
  square (`.position`-driven) and the parent `clipShape` contains the glow.

## Rejection semantics

Aerthys recognizes three specific visual reference samples, not lichens in
general. The rejection message is therefore:

- "No se reconoció la muestra"
- "Centra una de las muestras dentro del área de análisis e inténtalo nuevamente."

and not "No se detectó un líquen".

## Concurrency

- `CameraService` owns the whole AVFoundation stack (permission, session,
  back wide-angle input, `AVCapturePhotoOutput`, torch). `ScannerView` /
  `ScannerViewModel` only observe its published state. AVFoundation state
  is `nonisolated(unsafe)` and only mutated on a private serial
  `sessionQueue`.
- Torch is used as continuous illumination; the photo's `flashMode` is
  `.off`. Torch changes go through `lockForConfiguration()` and never
  crash when torch is unavailable.
- `AerthysReferenceMatcher` does all model work on a private serial queue,
  never on the caller's actor / main thread.
- The captured `UIImage` is never shown, saved, or uploaded — it only
  feeds the matcher.

## Reference tooling

The bundled reference set is produced by two macOS command-line Swift
scripts in `tools/` (not part of the app target):

- `tools/PrepareReferences.swift <root> [cropFraction] [outSize]` — reads
  raw photos from `<root>/References/{low,moderate,high}/`, applies the
  same centered square crop the app uses (`min(w,h) * cropFraction`,
  default `0.82`), resizes, and writes
  `<root>/Output/BundleReferences/{low,moderate,high}/*.jpg` plus
  `manifest.json`. That folder + manifest is what gets copied into
  `Aerthys/Resources/AerthysReferences/`. No feature prints are baked —
  the app computes them on-device so the Vision revision always matches.
- `tools/CalibrateMatcher.swift <root> [cropFraction]` — computes feature
  prints for the prepared references and for a reject-set under
  `<root>/Calibration/other/`, then reports leave-one-out separability,
  per-strategy accuracy, the confusion matrix, and a threshold sweep, and
  writes a calibration report. The `FEATURE_PRINT_REVISION` constant must
  equal the app's pinned revision.

## Tests

- The test target is hosted by the app (`TEST_HOST` / `BUNDLE_LOADER`) so
  `Bundle.main` resolves to the app bundle and the tests can load the real
  `AerthysReferences.json` + reference JPEGs.
- `AerthysTests/Fixtures/fixture_{low,moderate,high}.jpg` are full-frame
  photos of the three physical samples whose `cropFraction` crop is also
  in the active reference set, so the full pipeline must recognize each as
  its own class with a low reject score.
- The 3 end-to-end recognition tests skip in the Simulator because
  Vision's feature-print inference context can't spin up in that sandbox;
  run them on a physical iPhone. `AerthysMatchDecisionTests` covers the
  scoring logic without Vision.

## Scope

Aerthys is a demonstration of visual recognition by similarity.

It is **not**:
- a chemical sensor
- a professional air-quality meter
- a heavy-metals detector
- a universal lichen classifier
