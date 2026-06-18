//
//  CameraFeature.swift
//  Sniffle
//
//  Created by Victor on 2026/6/10.
//

import ComposableArchitecture
import CoreGraphics

fileprivate enum CameraFeatureCancelID: String, Sendable {
    case detectionHandler
    case permissionRequest
    case cameraStart
}

struct CameraFeature: Reducer {

    @Dependency(\.cameraClient) var cameraClient

    @ObservableState
    struct State {
        var isCameraOn = false
        var hasCameraPermission = false
        var desiredCameraOn = false
        var permissionDenied = false
        var detections: [CameraDetectionOverlayItem] = []
        var selectedDetection: CameraDetectionOverlayItem?
        var detectionImageSize: CGSize = .zero
        var showsAllDetections = false
    }

    enum Action {
        case onAppear
        case onDisappear
        case toggleCamera
        case toggleShowsAllDetections(Bool)
        case permissionResponse(Bool)
        case cameraStarted(Bool)
        case cameraTapped(CGPoint, CGSize)
        case detectionResult([CameraDetectionOverlayItem], CGSize)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.desiredCameraOn = true
                state.detections = []
                state.selectedDetection = nil
                state.detectionImageSize = .zero
                if state.hasCameraPermission {
                    return .merge(
                        detectionHandlerEffect(cameraClient: cameraClient),
                        .run { [cameraClient] send in
                            let started = await cameraClient.startCamera()
                            try Task.checkCancellation()
                            await send(.cameraStarted(started))
                        }
                        .cancellable(id: CameraFeatureCancelID.cameraStart, cancelInFlight: true)
                    )
                }

                return .merge(
                    detectionHandlerEffect(cameraClient: cameraClient),
                    .run { [cameraClient] send in
                        let granted = await cameraClient.requestPermission()
                        try Task.checkCancellation()
                        await send(.permissionResponse(granted))
                    }
                    .cancellable(id: CameraFeatureCancelID.permissionRequest, cancelInFlight: true)
                )

            case .onDisappear:
                state.desiredCameraOn = false
                state.isCameraOn = false
                state.permissionDenied = false
                state.detections = []
                state.selectedDetection = nil
                state.detectionImageSize = .zero
                return .merge(
                    .cancel(id: CameraFeatureCancelID.detectionHandler),
                    .cancel(id: CameraFeatureCancelID.permissionRequest),
                    .cancel(id: CameraFeatureCancelID.cameraStart),
                    .run { [cameraClient] _ in
                        cameraClient.clearDetectionHandler()
                        await cameraClient.stopCamera()
                    }
                )

            case let .cameraTapped(point, viewSize):
                let tappedDetection = aspectFillDisplayRects(
                    for: state.detections,
                    imageSize: state.detectionImageSize,
                    viewSize: viewSize
                )
                .filter { isFullyVisible($0.frame, in: viewSize) }
                .filter { $0.frame.contains(point) }
                .min { lhs, rhs in
                    (lhs.frame.width * lhs.frame.height) < (rhs.frame.width * rhs.frame.height)
                }?
                .detection

                state.selectedDetection = tappedDetection
                return .none

            case let .toggleShowsAllDetections(isOn):
                state.showsAllDetections = isOn
                if isOn {
                    state.selectedDetection = nil
                }
                return .none

            case let .detectionResult(detections, imageSize):
                state.detections = detections
                state.detectionImageSize = imageSize

                if state.showsAllDetections {
                    state.selectedDetection = nil
                } else if let selectedDetection = state.selectedDetection {
                    state.selectedDetection = bestMatch(for: selectedDetection, in: detections)
                }
                return .none

            case .toggleCamera:
                if state.isCameraOn {
                    state.desiredCameraOn = false
                    state.isCameraOn = false
                    state.permissionDenied = false
                    state.detections = []
                    state.selectedDetection = nil
                    state.detectionImageSize = .zero
                    return .merge(
                        .cancel(id: CameraFeatureCancelID.detectionHandler),
                        .cancel(id: CameraFeatureCancelID.permissionRequest),
                        .cancel(id: CameraFeatureCancelID.cameraStart),
                        .run { [cameraClient] _ in
                            await cameraClient.stopCamera()
                        }
                    )
                } else {
                    state.desiredCameraOn = true
                    state.permissionDenied = false

                    if state.hasCameraPermission {
                        return .merge(
                            detectionHandlerEffect(cameraClient: cameraClient),
                            .run { [cameraClient] send in
                                let started = await cameraClient.startCamera()
                                try Task.checkCancellation()
                                await send(.cameraStarted(started))
                            }
                            .cancellable(id: CameraFeatureCancelID.cameraStart, cancelInFlight: true)
                        )
                    }

                    return .merge(
                        detectionHandlerEffect(cameraClient: cameraClient),
                        .run { [cameraClient] send in
                            let granted = await cameraClient.requestPermission()
                            try Task.checkCancellation()
                            await send(.permissionResponse(granted))
                        }
                        .cancellable(id: CameraFeatureCancelID.permissionRequest, cancelInFlight: true)
                    )
                }

            case let .permissionResponse(granted):
                state.hasCameraPermission = granted

                guard granted else {
                    state.isCameraOn = false
                    state.permissionDenied = true
                    state.desiredCameraOn = false
                    state.detections = []
                    state.selectedDetection = nil
                    state.detectionImageSize = .zero
                    return .merge(
                        .cancel(id: CameraFeatureCancelID.detectionHandler),
                        .cancel(id: CameraFeatureCancelID.permissionRequest),
                        .cancel(id: CameraFeatureCancelID.cameraStart),
                        .run { [cameraClient] _ in
                            await cameraClient.stopCamera()
                        }
                    )
                }

                guard state.desiredCameraOn else {
                    state.permissionDenied = false
                    return .none
                }

                state.permissionDenied = false
                return .run { [cameraClient] send in
                    let started = await cameraClient.startCamera()
                    try Task.checkCancellation()
                    await send(.cameraStarted(started))
                }
                .cancellable(id: CameraFeatureCancelID.cameraStart, cancelInFlight: true)

            case let .cameraStarted(started):
                guard state.desiredCameraOn else {
                    state.isCameraOn = false
                    return .none
                }

                state.isCameraOn = started
                return .none
            }
        }
    }
}

private func detectionHandlerEffect(cameraClient: CameraClient) -> Effect<CameraFeature.Action> {
    .run { send in
        let stream = AsyncStream<([CameraDetectionOverlayItem], CGSize)> { continuation in
            cameraClient.setDetectionHandler { detections, imageSize in
                continuation.yield((detections, imageSize))
            }

            continuation.onTermination = { _ in
                cameraClient.clearDetectionHandler()
            }
        }

        for await (detections, imageSize) in stream {
            await send(.detectionResult(detections, imageSize))
        }
    }
    .cancellable(id: CameraFeatureCancelID.detectionHandler, cancelInFlight: true)
}

private func bestMatch(
    for selectedDetection: CameraDetectionOverlayItem,
    in detections: [CameraDetectionOverlayItem]
) -> CameraDetectionOverlayItem? {
    let candidate = detections
        .filter { $0.className == selectedDetection.className }
        .max { lhs, rhs in
            matchScore(lhs.normalizedRect, selectedDetection.normalizedRect)
                < matchScore(rhs.normalizedRect, selectedDetection.normalizedRect)
        }

    guard let candidate,
          matchScore(candidate.normalizedRect, selectedDetection.normalizedRect) > -0.35 else {
        return nil
    }

    return candidate
}

private func matchScore(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
    let intersection = lhs.intersection(rhs)
    let intersectionArea = max(0, intersection.width) * max(0, intersection.height)
    let unionArea = lhs.width * lhs.height + rhs.width * rhs.height - intersectionArea
    let iou = unionArea > 0 ? intersectionArea / unionArea : 0
    let centerDistance = hypot(lhs.midX - rhs.midX, lhs.midY - rhs.midY)

    return iou - centerDistance
}

private func isFullyVisible(_ frame: CGRect, in viewSize: CGSize) -> Bool {
    guard frame.width > 0, frame.height > 0 else { return false }

    let visibleBounds = CGRect(origin: .zero, size: viewSize)
    return visibleBounds.insetBy(dx: -2, dy: -2).contains(frame)
}
