import UIKit
import CoreGraphics
import ImageIO

enum ImagePreprocessor {
    struct Result {
        let cgImage: CGImage
        let orientation: CGImagePropertyOrientation
    }

    static func preprocess(_ image: UIImage) throws -> Result {
        guard let cgImage = image.cgImage else {
            throw ImagePreprocessingError.invalidImage
        }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else {
            throw ImagePreprocessingError.invalidImage
        }

        let side = CGFloat(min(width, height)) * AnalysisRegion.cropFraction
        guard side > 0 else {
            throw ImagePreprocessingError.invalidImage
        }

        let originX = (CGFloat(width) - side) / 2
        let originY = (CGFloat(height) - side) / 2
        let cropRect = CGRect(x: originX, y: originY, width: side, height: side)

        guard let cropped = cgImage.cropping(to: cropRect) else {
            throw ImagePreprocessingError.invalidImage
        }

        return Result(cgImage: cropped, orientation: CGImagePropertyOrientation(image.imageOrientation))
    }
}

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
