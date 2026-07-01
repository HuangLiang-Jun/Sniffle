//
//  CameraService.swift
//  Sniffle
//
//  Created by Victor on 2026/6/10.
//

import AVFoundation
import UltralyticsYOLO

final class CameraService: NSObject, @unchecked Sendable {

    static let shared = CameraService()

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "Sniffle.CameraService.session")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let modelDownloader = YOLOModelDownloader()
    private var modelURL: URL? {
        Bundle.main.url(forResource: "yolo26n", withExtension: "mlmodelc")
    }
    
    private let modelTask: YOLOTask = .detect
    private var currentInput: AVCaptureDeviceInput?
    private var predictor: BasePredictor?
    private var isLoadingModel = false
    private var isProcessingFrame = false
    private var lastDetectionPublishTime = Date.distantPast
    private let detectionPublishInterval: TimeInterval = 0.1

    var onDetectionsChanged: (([CameraDetectionOverlayItem], CGSize) -> Void)?

    func setDetectionHandler(
        _ handler: @escaping @Sendable ([CameraDetectionOverlayItem], CGSize) -> Void
    ) {
        sessionQueue.async {
            self.onDetectionsChanged = handler
        }
    }

    func clearDetectionHandler() {
        sessionQueue.async {
            self.onDetectionsChanged = nil
        }
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start() async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                let started = self.configureAndStartIfNeeded()
                if started {
                    self.bootstrapModelIfNeeded()
                }
                continuation.resume(returning: started)
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                if self.session.isRunning {
                    self.session.stopRunning()
                }
                continuation.resume()
            }
        }
    }

    func getSession() -> AVCaptureSession {
        session
    }

    private func configureAndStartIfNeeded() -> Bool {
        if session.isRunning {
            return true
        }

        session.beginConfiguration()
        var shouldStart = false
        defer {
            session.commitConfiguration()
            if shouldStart {
                session.startRunning()
            }
        }

        session.sessionPreset = .high

        if currentInput == nil {
            guard let device = defaultBackCamera(),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                return false
            }

            session.addInput(input)
            currentInput = input
        }

        if session.outputs.contains(where: { $0 === videoOutput }) == false {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)
            ]
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            guard session.canAddOutput(videoOutput) else {
                return false
            }
            session.addOutput(videoOutput)
        }

        if let connection = videoOutput.connection(with: .video) {
            connection.videoRotationAngle = 90
        }

        shouldStart = true
        return true
    }

    private func bootstrapModelIfNeeded() {
        guard predictor == nil, !isLoadingModel, let url = modelURL else { return }
        isLoadingModel = true
        BasePredictor.create(for: self.modelTask, modelURL: url, isRealTime: true) {
            [weak self] result in
            guard let self else { return }
            self.sessionQueue.async {
                self.isLoadingModel = false
                switch result {
                case let .success(predictor):
                    predictor.capturesOriginalImage = false
                    predictor.setConfidenceThreshold(confidence: 0.55)
                    predictor.setNumItemsThreshold(numItems: 5)
                    self.predictor = predictor
                case .failure(let error):
                    print("Failed to load YOLO predictor: \(error)")
                }
            }
        }
    }

    private func defaultBackCamera() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera,
                                for: .video,
                                position: .back)
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard output === videoOutput else { return }
        guard let predictor, !isProcessingFrame else {
            if predictor == nil {
                bootstrapModelIfNeeded()
            }
            return
        }

        isProcessingFrame = true
        predictor.isUpdating = true
        defer {
            predictor.isUpdating = false
            isProcessingFrame = false
        }

        predictor.predict(
            sampleBuffer: sampleBuffer,
            onResultsListener: self,
            onInferenceTime: self
        )
    }
}

extension CameraService: ResultsListener, InferenceTimeListener {
    func on(result: YOLOResult) {
        let now = Date()
        guard now.timeIntervalSince(lastDetectionPublishTime) >= detectionPublishInterval else {
            return
        }
        lastDetectionPublishTime = now

        let detections = result.boxes.enumerated().map { index, box in
            CameraDetectionOverlayItem(
                id: "\(index)-\(box.index)-\(box.cls)",
                normalizedRect: box.xywhn,
                className: box.cls,
                confidence: box.conf,
                colorIndex: box.index
            )
        }

        DispatchQueue.main.async { [weak self] in
            self?.onDetectionsChanged?(detections, result.orig_shape)
        }
    }

    func on(inferenceTime: Double, fpsRate: Double) {
        _ = inferenceTime
        _ = fpsRate
    }
}
