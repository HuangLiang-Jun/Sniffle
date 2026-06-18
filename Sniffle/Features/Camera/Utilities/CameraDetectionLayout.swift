//
//  CameraDetectionLayout.swift
//  Sniffle
//
//  Created by Victor on 2026/6/18.
//

import CoreGraphics

func aspectFillDisplayRects(
    for detections: [CameraDetectionOverlayItem],
    imageSize: CGSize,
    viewSize: CGSize
) -> [(detection: CameraDetectionOverlayItem, frame: CGRect)] {
    detections.map {
        (
            detection: $0,
            frame: aspectFillDisplayRect(
                for: $0.normalizedRect,
                imageSize: imageSize,
                viewSize: viewSize
            )
        )
    }
}

func aspectFillDisplayRect(
    for normalizedRect: CGRect,
    imageSize: CGSize,
    viewSize: CGSize
) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0, viewSize.width > 0, viewSize.height > 0 else {
        return .zero
    }

    let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
    let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    let offset = CGPoint(
        x: (scaledImageSize.width - viewSize.width) / 2,
        y: (scaledImageSize.height - viewSize.height) / 2
    )

    return CGRect(
        x: normalizedRect.minX * imageSize.width * scale - offset.x,
        y: normalizedRect.minY * imageSize.height * scale - offset.y,
        width: normalizedRect.width * imageSize.width * scale,
        height: normalizedRect.height * imageSize.height * scale
    )
}
