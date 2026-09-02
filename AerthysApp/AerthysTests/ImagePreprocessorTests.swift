import XCTest
@testable import Aerthys

final class ImagePreprocessorTests: XCTestCase {
    private func makeImage(width: Int, height: Int, orientation: UIImage.Orientation = .up) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let rendered = renderer.image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        guard let cgImage = rendered.cgImage else { return rendered }
        return UIImage(cgImage: cgImage, scale: 1, orientation: orientation)
    }

    func testCenterCropUsesTheShorterDimension() throws {
        let image = makeImage(width: 400, height: 200)
        let result = try ImagePreprocessor.preprocess(image)
        let expectedSide = Int(200 * AnalysisRegion.cropFraction)
        XCTAssertEqual(result.cgImage.width, expectedSide)
        XCTAssertEqual(result.cgImage.height, expectedSide)
    }

    func testCropIsAlwaysSquareAndSmallerThanTheSource() throws {
        let image = makeImage(width: 300, height: 300)
        let result = try ImagePreprocessor.preprocess(image)
        XCTAssertEqual(result.cgImage.width, result.cgImage.height)
        XCTAssertLessThan(result.cgImage.width, 300)
    }

    func testOrientationIsCarriedThroughUnchanged() throws {
        let image = makeImage(width: 300, height: 300, orientation: .right)
        let result = try ImagePreprocessor.preprocess(image)
        XCTAssertEqual(result.orientation, .right)
    }

    func testUpOrientationMapsToUp() throws {
        let image = makeImage(width: 120, height: 120, orientation: .up)
        let result = try ImagePreprocessor.preprocess(image)
        XCTAssertEqual(result.orientation, .up)
    }

    func testImageWithNoBackingPixelDataThrowsInvalidImage() {
        let empty = UIImage()
        XCTAssertThrowsError(try ImagePreprocessor.preprocess(empty)) { error in
            XCTAssertEqual(error as? ImagePreprocessingError, .invalidImage)
        }
    }
}
