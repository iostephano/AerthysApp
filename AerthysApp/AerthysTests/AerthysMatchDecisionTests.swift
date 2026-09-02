import XCTest
@testable import Aerthys

final class AerthysMatchDecisionTests: XCTestCase {

    private func d(_ label: AerthysReferenceClass, _ distance: Double) -> (label: AerthysReferenceClass, distance: Double) {
        (label, distance)
    }

    func testLowRecognizedAsLow() {
        let distances = [
            d(.low, 10), d(.low, 11), d(.low, 12), d(.low, 13), d(.low, 14),
            d(.moderate, 20), d(.high, 21),
        ]
        guard case .recognized(let cls, _) = AerthysMatchDecision.decide(distances: distances) else {
            return XCTFail("expected recognized")
        }
        XCTAssertEqual(cls, .low)
    }

    func testModerateRecognizedAsModerate() {
        let distances = [
            d(.moderate, 9), d(.moderate, 10), d(.moderate, 11), d(.moderate, 12), d(.moderate, 15),
            d(.low, 19), d(.high, 17),
        ]
        guard case .recognized(let cls, _) = AerthysMatchDecision.decide(distances: distances) else {
            return XCTFail("expected recognized")
        }
        XCTAssertEqual(cls, .moderate)
    }

    func testHighRecognizedAsHigh() {
        let distances = [
            d(.high, 8), d(.high, 9), d(.high, 10), d(.high, 11), d(.high, 12),
            d(.moderate, 16), d(.low, 22),
        ]
        guard case .recognized(let cls, _) = AerthysMatchDecision.decide(distances: distances) else {
            return XCTFail("expected recognized")
        }
        XCTAssertEqual(cls, .high)
    }

    func testKNNVoteBeatsSingleNearest() {
        let distances = [
            d(.high, 5),
            d(.moderate, 6), d(.moderate, 7), d(.moderate, 8), d(.moderate, 9),
            d(.low, 30),
        ]
        guard case .recognized(let cls, _) = AerthysMatchDecision.decide(distances: distances) else {
            return XCTFail("expected recognized")
        }
        XCTAssertEqual(cls, .moderate)
    }

    func testScoreExactlyAtThresholdIsAccepted() {
        let distances = [
            d(.low, 18.279), d(.low, 18.379), d(.low, 18.479), d(.low, 40), d(.low, 41),
            d(.moderate, 50), d(.high, 51),
        ]
        guard case .recognized(let cls, let score) = AerthysMatchDecision.decide(distances: distances) else {
            return XCTFail("expected recognized at threshold")
        }
        XCTAssertEqual(cls, .low)
        XCTAssertEqual(score, 18.379, accuracy: 0.0001)
    }

    func testScoreAboveThresholdIsRejected() {
        let distances = [
            d(.low, 19.5), d(.low, 19.5), d(.low, 19.5), d(.low, 19.5), d(.low, 19.5),
            d(.moderate, 25), d(.high, 26),
        ]
        guard case .rejected(let score) = AerthysMatchDecision.decide(distances: distances) else {
            return XCTFail("expected rejected")
        }
        XCTAssertEqual(score, 19.5, accuracy: 0.0001)
    }

    func testCalibratedConstantsMatchApprovedConfig() {
        XCTAssertEqual(AerthysMatchDecision.calibratedThreshold, 18.379, accuracy: 0.0001)
        XCTAssertEqual(AerthysMatchDecision.voteK, 5)
        XCTAssertEqual(AerthysMatchDecision.rejectScoreNearest, 3)
    }
}
