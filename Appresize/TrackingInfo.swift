//
//  TrackingInfo.swift
//  Hummingbird
//
//  Created by Sven A. Schmidt on 03/05/2019.
//  Copyright © 2019 finestructure. All rights reserved.
//

import Foundation
import Cocoa

/// The small window surface Tracker needs while an operation is active.
/// Production windows are backed by AXUIElement; tests provide an in-memory
/// implementation without creating an event tap or querying Accessibility.
struct TrackingWindow {
    let origin: () -> CGPoint?
    let size: () -> CGSize?
    let canSetOrigin: () -> Bool
    let canSetSize: () -> Bool
    let setOrigin: (CGPoint) -> Bool
    let setSize: (CGSize) -> Bool
}

class TrackingInfo {
    var time: CFTimeInterval = 0
    var window: TrackingWindow? = nil
    var origin: CGPoint = .zero
    var size: CGSize = .zero
    var corner: Corner = .bottomRight
    var location: CGPoint = .zero
    var initialOrigin: CGPoint = .zero
    var initialLocation: CGPoint = .zero

    func reset() {
        time = 0
        window = nil
        origin = .zero
        size = .zero
        corner = .bottomRight
        location = .zero
        initialOrigin = .zero
        initialLocation = .zero
    }
}
