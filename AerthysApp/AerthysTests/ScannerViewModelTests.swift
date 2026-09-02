import XCTest
@testable import Aerthys

@MainActor
final class ScannerViewModelTests: XCTestCase {
    func testStartsInCameraState() {
        let viewModel = ScannerViewModel()
        XCTAssertEqual(viewModel.state, .camera)
        XCTAssertFalse(viewModel.isBusy)
        XCTAssertNil(viewModel.assessment)
    }

    func testResetToCameraClearsResultStateAndReturnsToCamera() {
        let viewModel = ScannerViewModel()

        viewModel.resetToCamera()

        XCTAssertEqual(viewModel.state, .camera)
        XCTAssertNil(viewModel.capturedImage)
        XCTAssertNil(viewModel.assessment)
        XCTAssertFalse(viewModel.isBusy)
        XCTAssertEqual(viewModel.statusText, "Centra la muestra dentro del área de análisis")
    }

    func testRetryFromRejectionReturnsToCamera() {
        let viewModel = ScannerViewModel()

        viewModel.resetToCamera()

        XCTAssertEqual(viewModel.state, .camera)
        XCTAssertNil(viewModel.assessment)
        XCTAssertFalse(viewModel.isBusy)
    }
}
