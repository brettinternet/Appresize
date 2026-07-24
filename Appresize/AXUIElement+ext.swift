import Cocoa


extension AXUIElement {

    class func window(at position: CGPoint) -> AXUIElement? {
        guard isTrusted(prompt: false) else {
            return nil
        }
        
        var element: AXUIElement?
        var selected: AXUIElement?
        let systemwideElement = AXUIElementCreateSystemWide()
        let timeoutResult = AXUIElementSetMessagingTimeout(systemwideElement, 0.5)
        if timeoutResult != .success {
            log(.debug, "Could not set Accessibility messaging timeout: \(timeoutResult.rawValue)")
            return nil
        }

        withUnsafeMutablePointer(to: &element) { elementPtr in
            guard AXUIElementCopyElementAtPosition(
                systemwideElement,
                Float(position.x),
                Float(position.y),
                elementPtr
            ) == .success,
            let element = elementPtr.pointee else { return }

            var role: CFTypeRef?
            let roleResult = withUnsafeMutablePointer(to: &role) { rolePtr in
                AXUIElementCopyAttributeValue(element, NSAccessibility.Attribute.role as CFString, rolePtr)
            }
            if roleResult == .success,
               let role = role as? NSAccessibility.Role,
               role == .window {
                selected = element
            }

            var window: CFTypeRef?
            let windowResult = withUnsafeMutablePointer(to: &window) { windowPtr in
                AXUIElementCopyAttributeValue(element, NSAccessibility.Attribute.window as CFString, windowPtr)
            }
            if windowResult == .success,
               let window,
               CFGetTypeID(window) == AXUIElementGetTypeID() {
                // The CF type ID check makes this bridge safe without an unchecked cast.
                selected = unsafeBitCast(window, to: AXUIElement.self)
            }
        }

        return selected
    }


    var origin: CGPoint? {
        get {
            guard isTrusted(prompt: false) else { return nil }
            
            var pos = CGPoint.zero

            var ref: CFTypeRef?
            let success = withUnsafeMutablePointer(to: &ref) { refPtr -> Bool in
                switch AXUIElementCopyAttributeValue(self, NSAccessibility.Attribute.position as CFString, refPtr) {
                case .success:
                    guard let ref = refPtr.pointee,
                          CFGetTypeID(ref) == AXValueGetTypeID() else { break }
                    // The CF type ID check makes this bridge safe without an unchecked cast.
                    let value = unsafeBitCast(ref, to: AXValue.self)
                    guard AXValueGetType(value) == .cgPoint else { break }
                    let success = withUnsafeMutablePointer(to: &pos) { ptr in
                        AXValueGetValue(value, .cgPoint, ptr)
                    }
                    if !success {
                        log(.debug, "ERROR: Could not decode position")
                    }
                    return success
                default:
                    break
                }
                return false
            }

            return success ? pos : nil
        }
        set {
            guard isTrusted(prompt: false), var newValue = newValue else { return }
            let success = withUnsafePointer(to: &newValue) { ptr -> Bool in
                if let position = AXValueCreate(.cgPoint, ptr) {
                    switch AXUIElementSetAttributeValue(self, NSAccessibility.Attribute.position as CFString, position) {
                    case .success:
                        return true
                    default:
                        return false
                    }
                }
                return false
            }
            if !success {
                log(.debug, "ERROR: failed to set window origin")
            }
        }
    }


    var size: CGSize? {
        get {
            guard isTrusted(prompt: false) else { return nil }
            
            var size: CGSize = CGSize.zero

            var ref: CFTypeRef?
            let success = withUnsafeMutablePointer(to: &ref) { refPtr -> Bool in
                switch AXUIElementCopyAttributeValue(self, NSAccessibility.Attribute.size as CFString, refPtr) {
                case .success:
                    guard let ref = refPtr.pointee,
                          CFGetTypeID(ref) == AXValueGetTypeID() else { break }
                    // The CF type ID check makes this bridge safe without an unchecked cast.
                    let value = unsafeBitCast(ref, to: AXValue.self)
                    guard AXValueGetType(value) == .cgSize else { break }
                    let success = withUnsafeMutablePointer(to: &size) { sizePtr in
                        AXValueGetValue(value, .cgSize, sizePtr)
                    }
                    if !success {
                        log(.debug, "ERROR: Could not decode size")
                    }
                    return success
                default:
                    break
                }
                return false
            }

            return success ? size : nil
        }
        set {
            guard isTrusted(prompt: false), var newValue = newValue else { return }
            let success = withUnsafePointer(to: &newValue) { ptr -> Bool in
                if let size = AXValueCreate(.cgSize, ptr) {
                    switch AXUIElementSetAttributeValue(self, NSAccessibility.Attribute.size as CFString, size) {
                    case .success:
                        return true
                    default:
                        return false
                    }
                }
                return false
            }
            if !success {
                log(.debug, "ERROR: failed to set window size")
            }
        }
    }

}
