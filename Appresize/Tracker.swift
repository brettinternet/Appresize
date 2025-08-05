//
//  Tracker.swift
//  Hummingbird
//
//  Created by Sven A. Schmidt on 02/05/2019.
//  Copyright © 2019 finestructure. All rights reserved.
//

import Cocoa


class Tracker {

    // constants to throttle moving and resizing
    static let moveFilterInterval = 0.01
    static let resizeFilterInterval = 0.02

    static var shared: Tracker? = nil

    static func enable() {
        guard isTrusted(prompt: false) else {
            log(.debug, "❌ Cannot enable tracker: accessibility not trusted")
            return
        }
        shared = try? .init()
    }

    static func disable() {
        shared = nil
    }

    static var isActive: Bool {
        return shared != nil
    }


    private let trackingInfo = TrackingInfo()

    #if !TEST  // cannot populate these ivars when testing
    private let eventTap: CFMachPort
    private let runLoopSource: CFRunLoopSource?
    #endif

    private var currentState: State = .idle
    private var moveModifiers = Modifiers<Move>(forKey: .moveModifiers, defaults: Current.defaults())
    private var resizeModifiers = Modifiers<Resize>(forKey: .resizeModifiers, defaults: Current.defaults())
    private var requireDragToActivate: Bool = Current.defaults().bool(forKey: DefaultsKeys.requireDragToActivate.rawValue)
    private var accessibilityMonitorTimer: Timer?
    private var lastEventTime: CFAbsoluteTime = 0
    private static let maxEventAbsorptionTime: CFAbsoluteTime = 5.0  // Max 5 seconds of continuous absorption


    private init() throws {
        // don't enable tap for TEST or we'll trigger the permissions alert
        #if !TEST
        let res = try enableTap()
        self.eventTap = res.eventTap
        self.runLoopSource = res.runLoopSource
        NotificationCenter.default.addObserver(self, selector: #selector(readModifiers), name: UserDefaults.didChangeNotification, object: Current.defaults())
        startAccessibilityMonitoring()
        #endif
    }


    deinit {
        #if !TEST
        stopAccessibilityMonitoring()
        disableTap(eventTap: eventTap, runLoopSource: runLoopSource)
        NotificationCenter.default.removeObserver(self)
        #endif
    }


    @objc func readModifiers() {
        moveModifiers = Modifiers<Move>(forKey: .moveModifiers, defaults: Current.defaults())
        resizeModifiers = Modifiers<Resize>(forKey: .resizeModifiers, defaults: Current.defaults())
        requireDragToActivate = Current.defaults().bool(forKey: DefaultsKeys.requireDragToActivate.rawValue)
    }
    
    
    private func startAccessibilityMonitoring() {
        // Check accessibility permissions every 2 seconds
        accessibilityMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAccessibilityPermissions()
        }
    }
    
    
    private func stopAccessibilityMonitoring() {
        accessibilityMonitorTimer?.invalidate()
        accessibilityMonitorTimer = nil
    }
    
    
    @objc private func checkAccessibilityPermissions() {
        guard !isTrusted(prompt: false) else { return }
        
        log(.error, "⚠️ Accessibility permissions revoked - safely disabling tracker to prevent system freeze")
        
        // Safely disable the tracker on the main thread
        DispatchQueue.main.async {
            Tracker.disable()
        }
    }


    public func handleEvent(_ event: CGEvent, type: CGEventType) -> Bool {
        // Safety check: verify accessibility permissions are still granted
        guard isTrusted(prompt: false) else {
            log(.error, "⚠️ Accessibility permissions lost during event handling - aborting")
            DispatchQueue.main.async {
                Tracker.disable()
            }
            return false
        }
        
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // need to re-enable our eventTap (We got disabled. Usually happens on a slow resizing app)
            log(.debug, "Re-enabling")
            #if !TEST
            // Double-check permissions before re-enabling
            guard isTrusted(prompt: false) else {
                log(.error, "⚠️ Cannot re-enable tap: accessibility permissions lost")
                DispatchQueue.main.async {
                    Tracker.disable()
                }
                return false
            }
            CGEvent.tapEnable(tap: eventTap, enable: true)
            #endif
            return false
        }

        if moveModifiers.isEmpty && resizeModifiers.isEmpty { return false }

        // Check if we should respond to this event type based on drag-only setting
        let isDragEvent = type == .leftMouseDragged || type == .rightMouseDragged || type == .otherMouseDragged
        let isMoveEvent = type == .mouseMoved
        let isMouseButtonEvent = type == .leftMouseDown || type == .leftMouseUp || 
                                type == .rightMouseDown || type == .rightMouseUp ||
                                type == .otherMouseDown || type == .otherMouseUp
        
        // If we're currently in an active state (moving or resizing), absorb all mouse events
        // to prevent default actions like text selection
        if currentState != .idle && (isDragEvent || isMoveEvent || isMouseButtonEvent) {
            let currentTime = CFAbsoluteTimeGetCurrent()
            
            // Safety timeout: if we've been absorbing events for too long, reset to idle
            if lastEventTime > 0 && (currentTime - lastEventTime) > Self.maxEventAbsorptionTime {
                log(.error, "⚠️ Event absorption timeout - resetting to idle state to prevent system freeze")
                currentState = .idle
                lastEventTime = 0
                return false
            }
            
            if lastEventTime == 0 {
                lastEventTime = currentTime
            }
            
            let nextState = state(for: event.flags)
            
            switch (currentState, nextState) {
                case (.moving, .moving):
                    move(delta: event.mouseDelta)
                    return true  // Block all mouse events while moving
                case (.resizing, .resizing):
                    resize(delta: event.mouseDelta)
                    return true  // Block all mouse events while resizing
                case (.moving, .idle):
                    // Check for tiling when moving ends
                    checkForTiling(at: event.location)
                    currentState = nextState
                    lastEventTime = 0  // Reset timer when returning to idle
                    return true  // Block the final event that ends the operation
                case (.resizing, .idle):
                    currentState = nextState
                    lastEventTime = 0  // Reset timer when returning to idle
                    return true  // Block the final event that ends the operation
                case (.moving, .resizing):
                    TilingPreview.hidePreview()
                    startTracking(at: event.location)
                    currentState = nextState
                    return true  // Block transition events
                case (.resizing, .moving):
                    startTracking(at: event.location)
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

        var absortEvent = false
        let nextState = state(for: event.flags)

        switch (currentState, nextState) {
            // .idle -> X
            case (.idle, .idle):
                // event is not for us
                break
            case (.idle, .moving),
                 (.idle, .resizing):
                startTracking(at: event.location)
                absortEvent = true

            // .moving -> X
            case (.moving, .moving):
                move(delta: event.mouseDelta)
                absortEvent = true  // Block default actions while moving
            case (.moving, .idle):
                // Check for tiling when moving ends
                checkForTiling(at: event.location)
                break
            case (.moving, .resizing):
                TilingPreview.hidePreview()
                break

            // .resizing -> X
            case (.resizing, .idle):
                break
            case (.resizing, .moving):
                startTracking(at: event.location)
                absortEvent = true
            case (.resizing, .resizing):
                resize(delta: event.mouseDelta)
                absortEvent = true  // Block default actions while resizing
        }

        currentState = nextState

        return absortEvent
    }


    private func state(for modifiers: CGEventFlags) -> State {
        if moveModifiers.exclusivelySet(in: modifiers) {
            return .moving
        }
        if resizeModifiers.exclusivelySet(in: modifiers) {
            return .resizing
        }
        return .idle
    }


    private func startTracking(at location: CGPoint) {
        guard isTrusted(prompt: false) else {
            log(.debug, "❌ Accessibility not trusted, cannot track window")
            return
        }
        
        guard
            let trackedWindow = AXUIElement.window(at: location),
            let origin = trackedWindow.origin,
            let size = trackedWindow.size
        else { return }
        trackingInfo.time = CACurrentMediaTime()
        trackingInfo.window = trackedWindow
        trackingInfo.origin = origin
        trackingInfo.size = size
        if Current.defaults().bool(forKey: DefaultsKeys.resizeFromNearestCorner.rawValue) {
            trackingInfo.corner = .corner(for: location - origin, in: size)
        } else {
            trackingInfo.corner = .bottomRight
        }
    }


    private func move(delta: Delta) {
        guard let window = trackingInfo.window else {
            log(.debug, "No window!")
            return
        }

        trackingInfo.origin += delta
        
        // Update tiling preview if window tiling is enabled (do this every move, not just filtered)
        if Current.defaults().bool(forKey: DefaultsKeys.enableWindowTiling.rawValue) {
            let currentMouseLocation = NSEvent.mouseLocation
            print("🔵 Tracker: Updating tiling preview, mouse at: \(currentMouseLocation)")
            TilingPreview.updatePreview(at: currentMouseLocation)
        } else {
            print("🔵 Tracker: Window tiling disabled, not updating preview")
        }

        guard (CACurrentMediaTime() - trackingInfo.time) > Tracker.moveFilterInterval else { return }

        window.origin = trackingInfo.origin
        trackingInfo.time = CACurrentMediaTime()
    }


    private func resize(delta: Delta) {
        guard let window = trackingInfo.window else {
            log(.debug, "No window!")
            return
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

        guard (CACurrentMediaTime() - trackingInfo.time) > Tracker.resizeFilterInterval else { return }

        switch trackingInfo.corner {
            case .topLeft, .topRight, .bottomLeft:
                window.origin = trackingInfo.origin
                window.size = trackingInfo.size
            case .bottomRight:
                window.size = trackingInfo.size
        }

        trackingInfo.time = CACurrentMediaTime()
    }
    
    
    private func checkForTiling(at location: CGPoint) {
        // Always hide the preview when movement ends
        TilingPreview.hidePreview()
        
        guard let window = trackingInfo.window else {
            log(.debug, "🔴 checkForTiling: No window found")
            return
        }
        
        log(.debug, "🟡 checkForTiling: Checking tiling at location: \(location)")
        
        // Apply tiling if the window was moved near a screen edge
        let didTile = WindowTiling.applyTiling(to: window, at: location)
        log(.debug, didTile ? "🟢 Tiling applied!" : "🟡 No tiling applied")
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
