import XCTest
@testable import Aerthys

final class AnalysisRegionTests: XCTestCase {
    func testCropFractionIsAMathematicallyValidFraction() {
        XCTAssertGreaterThan(AnalysisRegion.cropFraction, 0)
        XCTAssertLessThanOrEqual(AnalysisRegion.cropFraction, 1)
    }

    func testCropFractionIsReasonablyGenerous() {
        XCTAssertGreaterThanOrEqual(AnalysisRegion.cropFraction, 0.4)
    }
}
