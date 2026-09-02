import AVFoundation
import Combine
import UIKit
import os.log

@MainActor
final class CameraService: NSObject, ObservableObject {

    enum PermissionState {
        case notDetermined
        case authorized
        case denied
    }

    @Published private(set) var permissionState: PermissionState = .notDetermined
    @Published private(set) var isSessionRunning = false
    @Published private(set) var isTorchOn = false
    @Published private(set) var isTorchAvailable = false

    nonisolated(unsafe) let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.example.aerthys.camera.sessionQueue", qos: .userInitiated)
    private nonisolated(unsafe) let photoOutput = AVCapturePhotoOutput()
    private nonisolated(unsafe) var videoDeviceInput: AVCaptureDeviceInput?
    private nonisolated(unsafe) var isConfigured = false

    private nonisolated(unsafe) var activePhotoCaptureDelegate: PhotoCaptureDelegate?

    private let log = Logger(subsystem: "com.example.aerthys", category: "CameraService")

    func requestAccessAndStart() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .authorized
            startSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionState = granted ? .authorized : .denied
            if granted {
                startSession()
            }
        default:
            permissionState = .denied
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureSessionIfNeeded()
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            let running = self.session.isRunning
            Task { @MainActor in
                self.isSessionRunning = running
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.setTorch(on: false)
            Task { @MainActor in
                self.isSessionRunning = false
            }
        }
    }

    private nonisolated func configureSessionIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            log.error("No back wide-angle camera available on this device.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                videoDeviceInput = input
            }
        } catch {
            log.error("Failed to create camera input: \(error.localizedDescription)")
            return
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        let torchAvailable = device.hasTorch && device.isTorchAvailable
        Task { @MainActor in
            self.isTorchAvailable = torchAvailable
        }
    }

    func toggleTorch() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let target = !self.currentTorchModeIsOn()
            self.setTorch(on: target)
        }
    }

    private nonisolated func currentTorchModeIsOn() -> Bool {
        videoDeviceInput?.device.torchMode == .on
    }

    private nonisolated func setTorch(on: Bool) {
        guard let device = videoDeviceInput?.device,
              device.hasTorch,
              device.isTorchAvailable else {
            return
        }

        let desiredMode: AVCaptureDevice.TorchMode = on ? .on : .off
        guard device.isTorchModeSupported(desiredMode) else { return }

        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
            Task { @MainActor in
                self.isTorchOn = on
            }
        } catch {
            log.error("Could not lock device for torch configuration: \(error.localizedDescription)")
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else {
                completion(nil)
                return
            }

            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off

            let delegate = PhotoCaptureDelegate { [weak self] image in
                self?.activePhotoCaptureDelegate = nil
                completion(image)
            }
            self.activePhotoCaptureDelegate = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void
    private let log = Logger(subsystem: "com.example.aerthys", category: "PhotoCapture")

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            log.error("Photo capture failed: \(error.localizedDescription)")
            deliver(nil)
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            log.error("Photo capture produced no usable image data.")
            deliver(nil)
            return
        }
        log.debug("Photo captured successfully: \(image.size.width, privacy: .public)x\(image.size.height, privacy: .public)")
        deliver(image)
    }

    private func deliver(_ image: UIImage?) {
        Task { @MainActor in
            completion(image)
        }
    }
}
