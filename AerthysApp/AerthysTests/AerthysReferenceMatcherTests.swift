import XCTest
import UIKit
@testable import Aerthys

final class AerthysReferenceMatcherTests: XCTestCase {

    private func fixture(_ name: String) throws -> UIImage {
        let bundle = Bundle(for: AerthysReferenceMatcherTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "jpg"),
                                "fixture \(name).jpg missing from the test bundle")
        return try XCTUnwrap(UIImage(contentsOfFile: url.path))
    }

    private func recognize(_ fixtureName: String) async throws -> (AerthysReferenceClass, Double) {
        let matcher = AerthysReferenceMatcher()
        let image = try fixture(fixtureName)
        do {
            switch try await matcher.match(image) {
            case .recognized(let cls, let score):
                return (cls, score)
            case .rejected(let score):
                XCTFail("\(fixtureName): reference-derived image was rejected (score \(score))")
                return (.low, score)
            }
        } catch let error as AerthysMatcherError {
            switch error {
            case .featurePrintFailed, .visionFailed, .noReferencePrints:
                throw XCTSkip("Vision feature-print context unavailable in this Simulator/XCTest environment — verify on a physical iPhone. (\(error))")
            case .referencesNotFound:
                XCTFail("AerthysReferences.json / images missing from the app bundle")
                return (.low, .infinity)
            case .deallocated:
                XCTFail("matcher deallocated mid-request")
                return (.low, .infinity)
            }
        }
    }

    func testLowSampleRecognizedAsLow() async throws {
        let (cls, score) = try await recognize("fixture_low")
        XCTAssertEqual(cls, .low)
        XCTAssertLessThanOrEqual(score, AerthysMatchDecision.calibratedThreshold)
    }

    func testModerateSampleRecognizedAsModerate() async throws {
        let (cls, score) = try await recognize("fixture_moderate")
        XCTAssertEqual(cls, .moderate)
        XCTAssertLessThanOrEqual(score, AerthysMatchDecision.calibratedThreshold)
    }

    func testHighSampleRecognizedAsHigh() async throws {
        let (cls, score) = try await recognize("fixture_high")
        XCTAssertEqual(cls, .high)
        XCTAssertLessThanOrEqual(score, AerthysMatchDecision.calibratedThreshold)
    }

    func testWarmUpDoesNotCrash() {
        AerthysReferenceMatcher().warmUp()
    }
}
