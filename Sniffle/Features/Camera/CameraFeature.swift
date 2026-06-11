//
//  CameraFeature.swift
//  Sniffle
//
//  Created by Victor on 2026/6/10.
//

import ComposableArchitecture

fileprivate enum CameraFeatureCancelID: String, Sendable {
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
    }

    enum Action {
        case onAppear
        case toggleCamera
        case permissionResponse(Bool)
        case cameraStarted(Bool)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.desiredCameraOn = true

                if state.hasCameraPermission {
                    return .run { [cameraClient] send in
                        let started = await cameraClient.startCamera()
                        try Task.checkCancellation()
                        await send(.cameraStarted(started))
                    }
                    .cancellable(id: CameraFeatureCancelID.cameraStart, cancelInFlight: true)
                }

                return .run { [cameraClient] send in
                    let granted = await cameraClient.requestPermission()
                    try Task.checkCancellation()
                    await send(.permissionResponse(granted))
                }
                .cancellable(id: CameraFeatureCancelID.permissionRequest, cancelInFlight: true)

            case .toggleCamera:
                if state.isCameraOn {
                    state.desiredCameraOn = false
                    state.isCameraOn = false
                    state.permissionDenied = false
                    return .merge(
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
                        return .run { [cameraClient] send in
                            let started = await cameraClient.startCamera()
                            try Task.checkCancellation()
                            await send(.cameraStarted(started))
                        }
                        .cancellable(id: CameraFeatureCancelID.cameraStart, cancelInFlight: true)
                    }

                    return .run { [cameraClient] send in
                        let granted = await cameraClient.requestPermission()
                        try Task.checkCancellation()
                        await send(.permissionResponse(granted))
                    }
                    .cancellable(id: CameraFeatureCancelID.permissionRequest, cancelInFlight: true)
                }

            case let .permissionResponse(granted):
                state.hasCameraPermission = granted

                guard granted else {
                    state.isCameraOn = false
                    state.permissionDenied = true
                    state.desiredCameraOn = false
                    return .merge(
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
