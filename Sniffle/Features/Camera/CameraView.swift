//
//  CameraView.swift
//  Sniffle
//
//  Created by Victor on 2026/6/10.
//

import ComposableArchitecture
import SwiftUI

struct CameraView: View {

    let store: StoreOf<CameraFeature>
    @State private var isPressed = false
    private let detectionColors: [Color] = [
        .green,
        .yellow,
        .cyan,
        .orange,
        .red,
        .mint,
        .blue,
        .pink
    ]

    var body: some View {
        ZStack {
            if store.isCameraOn {
                GeometryReader { proxy in
                    CameraPreview(session: CameraService.shared.getSession())
                        .ignoresSafeArea()
                        .overlay {
                            DetectionOverlay(
                                detections: store.detections,
                                selectedDetection: store.selectedDetection,
                                showsAllDetections: store.showsAllDetections,
                                imageSize: store.detectionImageSize,
                                colors: detectionColors
                            )
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    if store.showsAllDetections == false {
                                        store.send(.cameraTapped(value.location, proxy.size))
                                    }
                                }
                        )
                }
                .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            VStack(spacing: 12) {
                Spacer()

                if store.permissionDenied {
                    Text("請先允許相機權限")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.55), in: Capsule())
                }

                CameraBottomBar(
                    isCameraOn: store.isCameraOn,
                    showsAllDetections: Binding(
                        get: { store.showsAllDetections },
                        set: { store.send(.toggleShowsAllDetections($0)) }
                    ),
                    isPressed: isPressed,
                    onCameraTap: {
                        store.send(.toggleCamera)
                    },
                    onPressChanged: { isPressed in
                        self.isPressed = isPressed
                    }
                )
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
    }
}

private struct CameraBottomBar: View {
    let isCameraOn: Bool
    @Binding var showsAllDetections: Bool
    let isPressed: Bool
    let onCameraTap: () -> Void
    let onPressChanged: (Bool) -> Void

    var body: some View {
        ZStack(alignment: .center) {
            Button(action: onCameraTap) {
                ZStack {
                    Circle()
                        .fill(.thinMaterial)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.18), lineWidth: 1)
                        )

                    Image(systemName: isCameraOn ? "camera.fill" : "camera")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                }
                .frame(width: 76, height: 76)
            }
            .accessibilityLabel(isCameraOn ? "關閉相機" : "開啟相機")
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: isPressed)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.01)
                    .onChanged { _ in
                        onPressChanged(true)
                    }
                    .onEnded { _ in
                        onPressChanged(false)
                    }
            )

            HStack {
                VStack(spacing: 6) {
                    Text("全部偵測")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))

                    Toggle("全部偵測", isOn: $showsAllDetections)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(.green)
                }
                .frame(width: 86)

                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 132)
        .background(.black.opacity(0.58))
    }
}
