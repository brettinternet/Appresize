import Foundation

/// The visible portion of one display in Accessibility coordinates: the
/// primary display's top-left is zero and Y increases downward.
struct DisplayFrame {
    let visibleFrame: CGRect
}

func accessibilityDisplayFrames(
    appKitVisibleFrames: [CGRect],
    primaryFrame: CGRect
) -> [DisplayFrame] {
    appKitVisibleFrames.map { frame in
        DisplayFrame(visibleFrame: CGRect(
            x: frame.minX,
            y: primaryFrame.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        ))
    }
}

/// Keep the title bar usable while moving a window between displays. The
/// returned origin keeps the title bar fully inside the chosen display's
/// visible frame whenever the window is small enough to permit it.
func constrainedOrigin(
    proposed: CGPoint,
    windowSize: CGSize,
    displays: [DisplayFrame],
    titleBarHeight: CGFloat = 24,
    minimumVisibleTitleBarWidth: CGFloat = 80,
    referencePoint: CGPoint? = nil
) -> CGPoint {
    guard proposed.x.isFinite, proposed.y.isFinite,
          windowSize.width.isFinite, windowSize.height.isFinite,
          windowSize.width > 0, windowSize.height > 0,
          !displays.isEmpty else { return proposed }

    let target = referencePoint ?? proposed
    let display = displays.min {
        distance(from: target, to: $0.visibleFrame) < distance(from: target, to: $1.visibleFrame)
    }!
    let frame = display.visibleFrame
    let titleHeight = min(max(titleBarHeight, 0), windowSize.height)
    let titleWidth = min(max(minimumVisibleTitleBarWidth, 0), windowSize.width)

    let minX = frame.minX - windowSize.width + titleWidth
    let maxX = frame.maxX - titleWidth
    let minY = frame.minY
    let maxY = frame.maxY - titleHeight

    return CGPoint(
        x: min(max(proposed.x, minX), maxX),
        y: min(max(proposed.y, minY), maxY)
    )
}

private func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
    let dx: CGFloat
    if point.x < rect.minX { dx = rect.minX - point.x }
    else if point.x > rect.maxX { dx = point.x - rect.maxX }
    else { dx = 0 }
    let dy: CGFloat
    if point.y < rect.minY { dy = rect.minY - point.y }
    else if point.y > rect.maxY { dy = point.y - rect.maxY }
    else { dy = 0 }
    return dx * dx + dy * dy
}
