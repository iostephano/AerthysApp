import CoreGraphics

enum AnalysisRegion {
    static let cropFraction: CGFloat = 0.82

    static func frameSide(forContainerWidth width: CGFloat) -> CGFloat {
        max(0, width * cropFraction)
    }
}
