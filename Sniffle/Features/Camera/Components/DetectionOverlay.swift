//
//  DetectionOverlay.swift
//  Sniffle
//
//  Created by Victor on 2026/6/18.
//

import SwiftUI

struct DetectionOverlay: View {
    let detections: [CameraDetectionOverlayItem]
    let selectedDetection: CameraDetectionOverlayItem?
    let showsAllDetections: Bool
    let imageSize: CGSize
    let colors: [Color]

    var body: some View {
        GeometryReader { proxy in
            let viewSize = proxy.size

            ZStack(alignment: .topLeading) {
                ForEach(displayedDetections) { detection in
                    DetectionFrame(
                        detection: detection,
                        imageSize: imageSize,
                        viewSize: viewSize,
                        colors: colors
                    )
                }
            }
            .transaction { transaction in
                transaction.animation = nil
            }
        }
        .allowsHitTesting(false)
    }

    private var displayedDetections: [CameraDetectionOverlayItem] {
        if showsAllDetections {
            detections
        } else if let selectedDetection {
            [selectedDetection]
        } else {
            []
        }
    }
}
