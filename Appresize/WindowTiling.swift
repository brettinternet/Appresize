import Cocoa
import Foundation

enum TileZone {
    case none
    case left
    case right
    case top
    case bottom
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

struct TilingConstants {
    static let edgeThreshold: CGFloat = 50  // Distance from edge to trigger tiling
    static let cornerThreshold: CGFloat = 100  // Distance from corner to trigger corner tiling
}

class WindowTiling {
    
    /// Determines which tiling zone a point is in based on screen edges
    static func getTileZone(for point: CGPoint, in screenFrame: CGRect) -> TileZone {
        let leftEdge = screenFrame.minX
        let rightEdge = screenFrame.maxX
        let topEdge = screenFrame.maxY  // macOS coordinate system
        let bottomEdge = screenFrame.minY
        
        let isNearLeft = point.x - leftEdge <= TilingConstants.edgeThreshold
        let isNearRight = rightEdge - point.x <= TilingConstants.edgeThreshold
        let isNearTop = topEdge - point.y <= TilingConstants.edgeThreshold
        let isNearBottom = point.y - bottomEdge <= TilingConstants.edgeThreshold
        
        // Check corners first (smaller zones take priority)
        if isNearLeft && isNearTop {
            return .topLeft
        } else if isNearRight && isNearTop {
            return .topRight
        } else if isNearLeft && isNearBottom {
            return .bottomLeft
        } else if isNearRight && isNearBottom {
            return .bottomRight
        }
        // Check edges
        else if isNearLeft {
            return .left
        } else if isNearRight {
            return .right
        } else if isNearTop {
            return .top
        } else if isNearBottom {
            return .bottom
        }
        
        return .none
    }
    
    /// Calculates the target frame for a window based on the tile zone
    static func getTargetFrame(for zone: TileZone, in screenFrame: CGRect) -> CGRect {
        let screenWidth = screenFrame.width
        let screenHeight = screenFrame.height
        let screenX = screenFrame.minX
        let screenY = screenFrame.minY
        
        switch zone {
        case .left:
            return CGRect(x: screenX, y: screenY, width: screenWidth / 2, height: screenHeight)
        case .right:
            return CGRect(x: screenX + screenWidth / 2, y: screenY, width: screenWidth / 2, height: screenHeight)
        case .top:
            return CGRect(x: screenX, y: screenY + screenHeight / 2, width: screenWidth, height: screenHeight / 2)
        case .bottom:
            return CGRect(x: screenX, y: screenY, width: screenWidth, height: screenHeight / 2)
        case .topLeft:
            return CGRect(x: screenX, y: screenY + screenHeight / 2, width: screenWidth / 2, height: screenHeight / 2)
        case .topRight:
            return CGRect(x: screenX + screenWidth / 2, y: screenY + screenHeight / 2, width: screenWidth / 2, height: screenHeight / 2)
        case .bottomLeft:
            return CGRect(x: screenX, y: screenY, width: screenWidth / 2, height: screenHeight / 2)
        case .bottomRight:
            return CGRect(x: screenX + screenWidth / 2, y: screenY, width: screenWidth / 2, height: screenHeight / 2)
        case .none:
            return CGRect.zero
        }
    }
    
    /// Gets the screen frame that contains the given point
    static func getScreenFrame(containing point: CGPoint) -> CGRect? {
        guard let screens = NSScreen.screens as [NSScreen]? else { return nil }
        
        for screen in screens {
            if screen.frame.contains(point) {
                return screen.visibleFrame  // Use visibleFrame to account for menu bar and dock
            }
        }
        
        // Fallback to main screen if point is not in any screen
        return NSScreen.main?.visibleFrame
    }
    
    /// Applies tiling to a window based on the current mouse position
    static func applyTiling(to window: AXUIElement, at mousePosition: CGPoint) -> Bool {
        log(.debug, "🔵 applyTiling: Called with mouse position: \(mousePosition)")
        
        guard Current.defaults().bool(forKey: DefaultsKeys.enableWindowTiling.rawValue) else {
            log(.debug, "🔴 applyTiling: Window tiling is disabled in preferences")
            return false
        }
        
        guard let screenFrame = getScreenFrame(containing: mousePosition) else {
            log(.debug, "🔴 applyTiling: No screen found for mouse position: \(mousePosition)")
            return false
        }
        
        log(.debug, "🟡 applyTiling: Screen frame: \(screenFrame)")
        
        let tileZone = getTileZone(for: mousePosition, in: screenFrame)
        log(.debug, "🟡 applyTiling: Tile zone: \(tileZone)")
        
        guard tileZone != .none else {
            log(.debug, "🟡 applyTiling: No tiling zone detected")
            return false
        }
        
        let targetFrame = getTargetFrame(for: tileZone, in: screenFrame)
        
        guard targetFrame != CGRect.zero else {
            log(.debug, "🔴 applyTiling: Invalid target frame")
            return false
        }
        
        log(.debug, "🟢 applyTiling: Applying tiling \(tileZone) to frame: \(targetFrame)")
        
        // Apply the new frame to the window
        window.origin = targetFrame.origin
        window.size = targetFrame.size
        
        log(.debug, "🟢 applyTiling: Tiling applied successfully!")
        return true
    }
}