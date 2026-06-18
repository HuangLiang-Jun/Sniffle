//
//  DetectionFrame.swift
//  Sniffle
//
//  Created by Victor on 2026/6/18.
//
import SwiftUI

struct DetectionFrame: View {
    let detection: CameraDetectionOverlayItem
    let imageSize: CGSize
    let viewSize: CGSize
    let colors: [Color]
    
    var body: some View {
        let frame = aspectFillDisplayRect(
            for: detection.normalizedRect,
            imageSize: imageSize,
            viewSize: viewSize
        )
        let color = colors[detection.colorIndex % colors.count]
        
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(color, lineWidth: 3.5)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
        
        Text(detection.className)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.92), in: Capsule())
            .position(
                x: max(frame.minX + 44, frame.minX + min(frame.width * 0.5, 120)),
                y: max(frame.minY + 12, 18)
            )
    }
}
