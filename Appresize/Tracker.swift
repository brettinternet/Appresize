//
//  Tracker.swift
//  Hummingbird
//
//  Created by Sven A. Schmidt on 02/05/2019.
//  Copyright © 2019 finestructure. All rights reserved.
//

import Cocoa


class Tracker {

    enum CursorKind: Equatable {
        case move
        case resize(Corner)
    }

    struct Dependencies {
        var trusted: () -> Bool
        var windowAt: (CGPoint) -> TrackingWindow?
        var now: () -> CFAbsoluteTime
        var displays: () -> [DisplayFrame] = { [] }
        var cursorCurrent: () -> NSCursor = { NSCursor.arrow }
        var cursorSet: (NSCursor) -> Void = { $0.set() }
        var cursorFor: (CursorKind) -> NSCursor = { _ in NSCursor.arrow }
        var installEventTap: Bool

        static var live: Self {
            Self(
                trusted: { isTrusted(prompt: false) },
                windowAt: { AXUIElement.window(at: $0)?.trackingWindow },
                now: { CFAbsoluteTimeGetCurrent() },
                displays: {
                    let screens = NSScreen.screens
                    guard let primaryFrame = screens.first?.frame else { return [] }
                    return accessibilityDisplayFrames(
                        appKitVisibleFrames: screens.map(\.visibleFrame),
                        primaryFrame: primaryFrame
                    )
                },
                cursorCurrent: { NSCursor.currentSystem ?? NSCursor.arrow },
                cursorSet: { $0.set() },
                cursorFor: { kind in
                    switch kind {
                    case .move:
                        return NSCursor.closedHand
                    case .resize(.topLeft), .resize(.bottomRight):
                        return NSCursor.frameResize(position: .topLeft, directions: .all)
                    case .resize(.topRight), .resize(.bottomLeft):
                        return NSCursor.frameResize(position: .topRight, directions: .all)
                    }
                },
                installEventTap: true
            )
        }
    }

    // constants to throttle moving and resizing
    static let moveFilterInterval = 0.01
    static let resizeFilterInterval = 0.02

    static var shared: Tracker? = nil

    static func enable() {
        guard isTrusted(prompt: false) else {
            log(.debug, "❌ Cannot enable tracker: accessibility not trusted")
            return
        }
        do {
            shared = try .init()
        } catch {
            shared = nil
            log(.error, "Could not create mouse event tap: \(error)")
        }
    }

    static func disable() {
        shared?.resetTrackingState()
        shared = nil
    }

    static var isActive: Bool {
        return shared != nil
    }


    private let trackingInfo = TrackingInfo()

    private let dependencies: Dependencies
    private let eventTap: CFMachPort?
    private let runLoopSource: CFRunLoopSource?

    private var currentState: State = .idle
    private var moveModifiers = Modifiers<Move>(forKey: .moveModifiers, defaults: Current.defaults())
    private var resizeModifiers = Modifiers<Resize>(forKey: .resizeModifiers, defaults: Current.defaults())
    private var requireDragToActivate: Bool = Current.defaults().bool(forKey: DefaultsKeys.requireDragToActivate.rawValue)
    private var lastEventTime: CFAbsoluteTime = 0
    private var activeDragButton: Int64?
    private var priorCursor: NSCursor?
    private var activeCursor: CursorKind?
    private static let maxEventAbsorptionTime: CFAbsoluteTime = 5.0  // Max 5 seconds of continuous absorption


    init(dependencies: Dependencies = .live) throws {
        self.dependencies = dependencies
        if dependencies.installEventTap {
            let res = try enableTap()
            self.eventTap = res.eventTap
            self.runLoopSource = res.runLoopSource
        } else {
            self.eventTap = nil
            self.runLoopSource = nil
        }
        if dependencies.installEventTap {
            NotificationCenter.default.addObserver(self, selector: #selector(readModifiers), name: UserDefaults.didChangeNotification, object: Current.defaults())
        }
    }


    deinit {
        resetTrackingState()
        if let eventTap {
            disableTap(eventTap: eventTap, runLoopSource: runLoopSource)
        }
        NotificationCenter.default.removeObserver(self)
    }


    @objc func readModifiers() {
        moveModifiers = Modifiers<Move>(forKey: .moveModifiers, defaults: Current.defaults())
        resizeModifiers = Modifiers<Resize>(forKey: .resizeModifiers, defaults: Current.defaults())
        requireDragToActivate = Current.defaults().bool(forKey: DefaultsKeys.requireDragToActivate.rawValue)
    }
    public func handleEvent(_ event: CGEvent, type: CGEventType) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            guard dependencies.trusted() else {
                resetTrackingState()
                DispatchQueue.main.async { Tracker.disable() }
                return false
            }
            // need to re-enable our eventTap (We got disabled. Usually happens on a slow resizing app)
            log(.debug, "Re-enabling")
            resetTrackingState()
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return false
        }

        // Check if we should respond to this event type based on drag-only setting
        let isDragEvent = type == .leftMouseDragged || type == .rightMouseDragged || type == .otherMouseDragged
        let isMoveEvent = type == .mouseMoved
        let isMouseButtonEvent = type == .leftMouseDown || type == .leftMouseUp || 
                                type == .rightMouseDown || type == .rightMouseUp ||
                                type == .otherMouseDown || type == .otherMouseUp
        let isMouseUp = type == .leftMouseUp || type == .rightMouseUp || type == .otherMouseUp

        // Drag-only mode must not consume button transitions. Once a drag has
        // actually started, use its button to identify the matching mouse-up
        // and end the operation before the up event reaches the system.
        if requireDragToActivate {
            if isMouseUp,
               let storedButton = activeDragButton,
               event.getIntegerValueField(.mouseEventButtonNumber) == storedButton {
                resetTrackingState()
                return false
            }
            if isMouseButtonEvent { return false }
        }

        if moveModifiers.isEmpty && resizeModifiers.isEmpty { return false }

        // If we're currently in an active state (moving or resizing), absorb all mouse events
        // to prevent default actions like text selection
        if currentState != .idle && (isDragEvent || isMoveEvent || isMouseButtonEvent) {
            guard dependencies.trusted() else {
                log(.error, "⚠️ Accessibility permissions lost during event handling - aborting")
                resetTrackingState()
                DispatchQueue.main.async { Tracker.disable() }
                return false
            }
            let currentTime = dependencies.now()
            
            // Safety timeout: if we've been absorbing events for too long, reset to idle
            if lastEventTime > 0 && (currentTime - lastEventTime) > Self.maxEventAbsorptionTime {
                log(.error, "⚠️ Event absorption timeout - resetting to idle state to prevent system freeze")
                resetTrackingState()
                return false
            }
            
            if lastEventTime == 0 {
                lastEventTime = currentTime
            }
            
            let nextState = state(for: event.flags)
            
            switch (currentState, nextState) {
                case (.moving, .moving):
                    let handled = move(delta: event.mouseDelta, pointerLocation: event.location)
                    if handled { lastEventTime = currentTime }
                    return handled  // Block all mouse events while moving
                case (.resizing, .resizing):
                    let handled = resize(delta: event.mouseDelta)
                    if handled { lastEventTime = currentTime }
                    return handled  // Block all mouse events while resizing
                case (.moving, .idle), (.resizing, .idle):
                    resetTrackingState()
                    return isMouseButtonEvent ? false : true  // Pass button transitions through
                case (.moving, .resizing):
                    guard startTracking(at: event.location, state: nextState) else {
                        resetTrackingState()
                        return false
                    }
                    currentState = nextState
                    return true  // Block transition events
                case (.resizing, .moving):
                    guard startTracking(at: event.location, state: nextState) else {
                        resetTrackingState()
                        return false
                    }
                    currentState = nextState
                    return true  // Block transition events
                default:
                    break
            }
        }

        if requireDragToActivate && !isDragEvent {
            return false  // Only respond to drag events when drag-only mode is enabled
        }

        if !requireDragToActivate && !isMoveEvent && !isDragEvent {
            return false  // In normal mode, respond to both move and drag events
        }

        var absorbEvent = false
        let nextState = state(for: event.flags)

        guard nextState != .idle else { return false }
        guard dependencies.trusted() else {
            log(.error, "⚠️ Accessibility permission unavailable; passing event through")
            return false
        }

        switch (currentState, nextState) {
            // .idle -> X
            case (.idle, .idle):
                // event is not for us
                break
            case (.idle, .moving),
                 (.idle, .resizing):
                guard startTracking(at: event.location, state: nextState) else {
                    resetTrackingState()
                    return false
                }
                if requireDragToActivate {
                    activeDragButton = event.getIntegerValueField(.mouseEventButtonNumber)
                }
                absorbEvent = true

            // .moving -> X
            case (.moving, .moving):
                absorbEvent = move(
                    delta: event.mouseDelta,
                    pointerLocation: event.location
                )  // Block default actions while moving
            case (.moving, .idle),
                 (.moving, .resizing):
                break

            // .resizing -> X
            case (.resizing, .idle):
                break
            case (.resizing, .moving):
                guard startTracking(at: event.location, state: nextState) else {
                    resetTrackingState()
                    return false
                }
                if requireDragToActivate {
                    activeDragButton = event.getIntegerValueField(.mouseEventButtonNumber)
                }
                absorbEvent = true
            case (.resizing, .resizing):
                absorbEvent = resize(delta: event.mouseDelta)  // Block default actions while resizing
        }

        currentState = nextState

        return absorbEvent
    }


    private func resetTrackingState() {
        restoreCursor()
        currentState = .idle
        lastEventTime = 0
        activeDragButton = nil
        trackingInfo.reset()
    }

    private func setCursor(for kind: CursorKind) {
        if priorCursor == nil {
            priorCursor = dependencies.cursorCurrent()
        }
        guard activeCursor != kind else { return }
        dependencies.cursorSet(dependencies.cursorFor(kind))
        activeCursor = kind
    }

    private func restoreCursor() {
        guard let priorCursor else { return }
        dependencies.cursorSet(priorCursor)
        self.priorCursor = nil
        activeCursor = nil
    }


    private func state(for modifiers: CGEventFlags) -> State {
        guard !modifierBindingsConflict(move: moveModifiers, resize: resizeModifiers) else {
            return .idle
        }
        if moveModifiers.exclusivelySet(in: modifiers) {
            return .moving
        }
        if resizeModifiers.exclusivelySet(in: modifiers) {
            return .resizing
        }
        return .idle
    }


    @discardableResult
    private func startTracking(at location: CGPoint, state: State) -> Bool {
        trackingInfo.reset()

        guard let trackedWindow = dependencies.windowAt(location),
              let origin = trackedWindow.origin(),
              let size = trackedWindow.size() else { return false }

        let corner = Current.defaults().bool(forKey: DefaultsKeys.resizeFromNearestCorner.rawValue)
            ? Corner.corner(for: location - origin, in: size)
            : .bottomRight
        switch state {
        case .moving:
            guard trackedWindow.canSetOrigin() else { return false }
        case .resizing:
            guard trackedWindow.canSetSize() else { return false }
            if case .bottomRight = corner {
                break
            } else {
                guard trackedWindow.canSetOrigin() else { return false }
            }
        case .idle:
            return false
        }

        trackingInfo.time = dependencies.now()
        lastEventTime = trackingInfo.time
        trackingInfo.window = trackedWindow
        trackingInfo.origin = origin
        trackingInfo.size = size
        trackingInfo.corner = corner
        setCursor(for: state == .moving ? .move : .resize(corner))
        return true
    }


    private func move(delta: Delta, pointerLocation: CGPoint) -> Bool {
        guard let window = trackingInfo.window else {
            log(.debug, "No window!")
            resetTrackingState()
            return false
        }

        trackingInfo.origin = constrainedOrigin(
            proposed: trackingInfo.origin + delta,
            windowSize: trackingInfo.size,
            displays: dependencies.displays(),
            referencePoint: pointerLocation
        )

        guard (dependencies.now() - trackingInfo.time) > Tracker.moveFilterInterval else { return true }

        guard window.setOrigin(trackingInfo.origin), let appliedOrigin = window.origin() else {
            resetTrackingState()
            return false
        }
        trackingInfo.origin = appliedOrigin
        trackingInfo.time = dependencies.now()
        return true
    }


    private func resize(delta: Delta) -> Bool {
        guard let window = trackingInfo.window else {
            log(.debug, "No window!")
            resetTrackingState()
            return false
        }

        switch trackingInfo.corner {
            case .topLeft:
                trackingInfo.origin += delta
                trackingInfo.size -= delta
            case .topRight:
                trackingInfo.origin += Delta(dx: 0, dy: delta.dy)
                trackingInfo.size += Delta(dx: delta.dx, dy: -delta.dy)
            case .bottomRight:
                trackingInfo.size += delta
            case .bottomLeft:
                trackingInfo.origin += Delta(dx: delta.dx, dy: 0)
                trackingInfo.size += Delta(dx: -delta.dx, dy: delta.dy)
        }

        guard trackingInfo.origin.x.isFinite, trackingInfo.origin.y.isFinite,
              trackingInfo.size.width.isFinite, trackingInfo.size.height.isFinite else {
            resetTrackingState()
            return false
        }

        let fixedRightEdge = trackingInfo.origin.x + trackingInfo.size.width
        let fixedBottomEdge = trackingInfo.origin.y + trackingInfo.size.height
        if trackingInfo.size.width < 1 {
            trackingInfo.size.width = 1
            if trackingInfo.corner == .topLeft || trackingInfo.corner == .bottomLeft {
                trackingInfo.origin.x = fixedRightEdge - trackingInfo.size.width
            }
        }
        if trackingInfo.size.height < 1 {
            trackingInfo.size.height = 1
            if trackingInfo.corner == .topLeft || trackingInfo.corner == .topRight {
                trackingInfo.origin.y = fixedBottomEdge - trackingInfo.size.height
            }
        }

        guard (dependencies.now() - trackingInfo.time) > Tracker.resizeFilterInterval else { return true }

        let requestedOrigin = trackingInfo.origin
        let requestedSize = trackingInfo.size
        guard window.setSize(requestedSize), let appliedSize = window.size() else {
            resetTrackingState()
            return false
        }

        let appliedRequestedOrigin: CGPoint
        switch trackingInfo.corner {
            case .topLeft:
                appliedRequestedOrigin = CGPoint(
                    x: requestedOrigin.x + requestedSize.width - appliedSize.width,
                    y: requestedOrigin.y + requestedSize.height - appliedSize.height
                )
            case .topRight:
                appliedRequestedOrigin = CGPoint(
                    x: requestedOrigin.x,
                    y: requestedOrigin.y + requestedSize.height - appliedSize.height
                )
            case .bottomRight:
                appliedRequestedOrigin = requestedOrigin
            case .bottomLeft:
                appliedRequestedOrigin = CGPoint(
                    x: requestedOrigin.x + requestedSize.width - appliedSize.width,
                    y: requestedOrigin.y
                )
        }

        if trackingInfo.corner != .bottomRight && !window.setOrigin(appliedRequestedOrigin) {
            resetTrackingState()
            return false
        }
        guard let appliedOrigin = window.origin() else {
            resetTrackingState()
            return false
        }
        trackingInfo.origin = appliedOrigin
        trackingInfo.size = appliedSize
        trackingInfo.time = dependencies.now()
        return true
    }

}


extension Tracker {
    enum Error: Swift.Error {
        case tapCreateFailed
    }
}


private func enableTap() throws -> (eventTap: CFMachPort, runLoopSource: CFRunLoopSource?)  {
    // https://stackoverflow.com/a/31898592/1444152

    let mouseMoved = 1 << CGEventType.mouseMoved.rawValue
    let leftDragged = 1 << CGEventType.leftMouseDragged.rawValue
    let rightDragged = 1 << CGEventType.rightMouseDragged.rawValue
    let otherDragged = 1 << CGEventType.otherMouseDragged.rawValue
    let leftDown = 1 << CGEventType.leftMouseDown.rawValue
    let leftUp = 1 << CGEventType.leftMouseUp.rawValue
    let rightDown = 1 << CGEventType.rightMouseDown.rawValue
    let rightUp = 1 << CGEventType.rightMouseUp.rawValue
    let otherDown = 1 << CGEventType.otherMouseDown.rawValue
    let otherUp = 1 << CGEventType.otherMouseUp.rawValue
    
    let eventMask = mouseMoved | leftDragged | rightDragged | otherDragged |
                    leftDown | leftUp | rightDown | rightUp | otherDown | otherUp
    guard let eventTap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: myCGEventCallback,
        userInfo: nil
    ) else {
        throw Tracker.Error.tapCreateFailed
    }

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)

    return (eventTap: eventTap, runLoopSource: runLoopSource)
}


private func disableTap(eventTap: CFMachPort, runLoopSource: CFRunLoopSource?) {
    log(.debug, "Disabling event tap")
    CGEvent.tapEnable(tap: eventTap, enable: false)
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes);
}


private func myCGEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {

    guard let tracker = Tracker.shared else {
        log(.debug, "🔴 tracker must not be nil")
        return Unmanaged.passUnretained(event)
    }

    let absorbEvent = tracker.handleEvent(event, type: type)

    return absorbEvent ? nil : Unmanaged.passUnretained(event)
}
