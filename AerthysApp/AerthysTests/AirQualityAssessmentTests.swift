import XCTest
@testable import Aerthys

final class AirQualityAssessmentTests: XCTestCase {

    func testReferenceClassMapsDirectlyToAssessment() {
        XCTAssertEqual(AirQualityAssessment(.low), .low)
        XCTAssertEqual(AirQualityAssessment(.moderate), .moderate)
        XCTAssertEqual(AirQualityAssessment(.high), .high)
    }
}
