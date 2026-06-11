//
//  SniffleApp.swift
//  Sniffle
//
//  Created by Victor on 2026/6/10.
//

import ComposableArchitecture
import SwiftUI

@main
struct SniffleApp: App {
    var body: some Scene {
        WindowGroup {
            CameraView(
                store: Store(
                    initialState: CameraFeature.State()
                ) {
                    CameraFeature()
                }
            )
        }
    }
}
