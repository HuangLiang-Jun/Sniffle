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

    var body: some View {
        ZStack {
            if store.isCameraOn {
                CameraPreview(session: CameraService.shared.getSession())
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

                Button {
                    store.send(.toggleCamera)
                } label: {
                    ZStack {
                        Circle()
                            .fill(.thinMaterial)
                            .overlay(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.16),
                                                Color.white.opacity(0.06),
                                                Color.clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .blendMode(.screen)
                            )
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.16), lineWidth: 1)
                            )
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.08), lineWidth: 0.5)
                            )

                        Image(systemName: store.isCameraOn ? "camera.fill" : "camera")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .frame(width: 78, height: 78)
                }
                .accessibilityLabel(store.isCameraOn ? "關閉相機" : "開啟相機")
                .scaleEffect(isPressed ? 0.92 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.68), value: isPressed)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.01)
                        .onChanged { _ in
                            isPressed = true
                        }
                        .onEnded { _ in
                            isPressed = false
                        }
                )
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}
