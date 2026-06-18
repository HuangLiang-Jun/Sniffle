//
//  CameraDetectionOverlayItem.swift
//  Sniffle
//
//  Created by Victor on 2026/6/18.
//

import CoreGraphics

struct CameraDetectionOverlayItem: Identifiable, Equatable, Sendable {
      
    let id: String
    let normalizedRect: CGRect
    let className: String
    let confidence: Float
    let colorIndex: Int
    
    init(id: String, normalizedRect: CGRect, className: String, confidence: Float, colorIndex: Int) {
        self.id = id
        self.normalizedRect = normalizedRect
        self.className = className
        self.confidence = confidence
        self.colorIndex = colorIndex
    }
    
    init() {
        self.id = ""
        self.normalizedRect = .zero
        self.className = ""
        self.confidence = 0
        self.colorIndex = 0
    }
}
