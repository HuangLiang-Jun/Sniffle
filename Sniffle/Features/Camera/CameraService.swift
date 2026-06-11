//
//  CameraService.swift
//  Sniffle
//
//  Created by Victor on 2026/6/10.
//

import AVFoundation

final class CameraService: @unchecked Sendable {

    static let shared = CameraService()

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "Sniffle.CameraService.session")
    private var currentInput: AVCaptureDeviceInput?

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

        shouldStart = true
        return true
    }

    private func defaultBackCamera() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera,
                                for: .video,
                                position: .back)
    }
}
