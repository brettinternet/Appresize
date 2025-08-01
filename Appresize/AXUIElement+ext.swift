import Cocoa


extension AXUIElement {

    class func window(at position: CGPoint) -> AXUIElement? {
        guard isTrusted(prompt: false) else {
            return nil
        }
        
        var element: AXUIElement?
        var selected: AXUIElement?
        let systemwideElement = AXUIElementCreateSystemWide()

        withUnsafeMutablePointer(to: &element) { elementPtr in
            if .success == AXUIElementCopyElementAtPosition(systemwideElement, Float(position.x), Float(position.y), elementPtr) {
                guard let element = elementPtr.pointee else { return }
                do {
                    var role: CFTypeRef?
                    withUnsafeMutablePointer(to: &role) { rolePtr in
                        if
                            .success == AXUIElementCopyAttributeValue(element, NSAccessibility.Attribute.role as CFString, rolePtr),
                            let r = rolePtr.pointee as? NSAccessibility.Role,
                            r == .window {
                            selected = element
                        }
                    }
                }
                do {
                    var window: CFTypeRef?
                    withUnsafeMutablePointer(to: &window) { windowPtr in
                        if .success == AXUIElementCopyAttributeValue(element, NSAccessibility.Attribute.window as CFString, windowPtr) {
                            selected = (windowPtr.pointee as! AXUIElement)
                        }
                    }
                }
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
                    guard let ref = refPtr.pointee else { break }
                    let success = withUnsafeMutablePointer(to: &pos) { ptr in
                        AXValueGetValue(ref as! AXValue, .cgPoint, ptr)
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
                    guard let ref = refPtr.pointee else { break }
                    let success = withUnsafeMutablePointer(to: &size) { sizePtr in
                        AXValueGetValue(ref as! AXValue, .cgSize, sizePtr)
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
