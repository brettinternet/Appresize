import Cocoa
import Foundation

class TilingPreview {
    private static var previewWindow: NSWindow?
    private static var currentZone: TileZone = .none
    
    /// Shows a preview overlay for the tiling zone
    static func showPreview(for zone: TileZone, in screenFrame: CGRect) {
        print("🟦 showPreview called with zone: \(zone), screenFrame: \(screenFrame)")
        
        // Don't show preview if zone hasn't changed
        if zone == currentZone && previewWindow != nil {
            print("🟦 showPreview: Zone unchanged, skipping")
            return
        }
        
        hidePreview()
        currentZone = zone
        
        guard zone != .none else { 
            print("🟦 showPreview: Zone is .none, not showing preview")
            return 
        }
        
        let targetFrame = WindowTiling.getTargetFrame(for: zone, in: screenFrame)
        guard targetFrame != CGRect.zero else { 
            print("🟦 showPreview: Invalid target frame")
            return 
        }
        
        // Create preview window
        let window = NSWindow(
            contentRect: targetFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.level = .popUpMenu
        window.isOpaque = false
        window.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.3)
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Add border
        let contentView = NSView(frame: window.contentRect(forFrameRect: targetFrame))
        contentView.wantsLayer = true
        contentView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
        contentView.layer?.borderWidth = 2.0
        contentView.layer?.cornerRadius = 8.0
        window.contentView = contentView
        
        window.orderFrontRegardless()
        previewWindow = window
        
        log(.debug, "🟦 Showing tiling preview for zone: \(zone)")
    }
    
    /// Hides the preview overlay
    static func hidePreview() {
        previewWindow?.orderOut(nil)
        previewWindow = nil
        currentZone = .none
        
        log(.debug, "🟦 Hiding tiling preview")
    }
    
    /// Updates preview during window movement
    static func updatePreview(at mousePosition: CGPoint) {
        print("🟦 updatePreview called with mouse position: \(mousePosition)")
        
        guard let screenFrame = WindowTiling.getScreenFrame(containing: mousePosition) else {
            print("🟦 updatePreview: No screen frame found, hiding preview")
            hidePreview()
            return
        }
        
        let zone = WindowTiling.getTileZone(for: mousePosition, in: screenFrame)
        print("🟦 updatePreview: Detected zone: \(zone)")
        showPreview(for: zone, in: screenFrame)
    }
}