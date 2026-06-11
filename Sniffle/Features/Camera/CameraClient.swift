//
//  CameraClient.swift
//  Sniffle
//
//  Created by Victor on 2026/6/10.
//

import AVFoundation
import Dependencies

struct CameraClient: Sendable {
    var requestPermission: @Sendable () async -> Bool
    var startCamera: @Sendable () async -> Bool
    var stopCamera: @Sendable () async -> Void
}

extension DependencyValues {
    var cameraClient: CameraClient {
        get { self[CameraClient.self] }
        set { self[CameraClient.self] = newValue }
    }
}

extension CameraClient: DependencyKey {
    static let liveValue = CameraClient(
        requestPermission: {
            await CameraService.shared.requestPermission()
        },
        startCamera: {
            await CameraService.shared.start()
        },
        stopCamera: {
            await CameraService.shared.stop()
        }
    )
}
