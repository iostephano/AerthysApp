# Aerthys Calibration

## Reference Set

49 references:

- LOW: 18
- MODERATE: 18
- HIGH: 13

Background: white matte background.

cropFraction: 0.82

Vision: `VNGenerateImageFeaturePrintRequest` Revision 1

Matching: 5-NN vote

rejectScore: mean of the 3 nearest distances to the voted class

threshold: 18.379

## Final Calibration Results

Leave-one-out accuracy:

- LOW: 100% (18/18)
- MODERATE: 100% (18/18)
- HIGH: 100% (13/13)
- Global: 100%

Confusion matrix:

```
            low  moderate  high
low          18     0        0
moderate      0    18        0
high          0     0       13
```

Rejection:

- Maximum reference reject score: 15.773
- Minimum global "other" score: 20.984
- Margin: +5.211
- Threshold: 18.379
- Reference acceptance: 100%
- Other rejection: 100%
- White-background "other" rejection: 100%

## Important Scope

These results describe the controlled reference set this demo ships with.
They are **not** a measure of universal accuracy on any lichen or any
environment.

Aerthys is calibrated to recognize three specific reference groups
(LOW / MODERATE / HIGH) photographed on a white matte background, and to
reject anything that isn't close enough to one of them. Replacing the
reference images requires re-running `tools/PrepareReferences.swift` then
`tools/CalibrateMatcher.swift` and updating
`AerthysMatchDecision.calibratedThreshold` to the newly recommended value.
