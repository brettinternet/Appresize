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

/// Keep enough of the title bar reachable while moving a window between
/// displays. Each display contributes a rectangle of valid window origins;
/// the proposed origin is only adjusted when it falls outside the union of
/// those rectangles.
func constrainedOrigin(
    proposed: CGPoint,
    windowSize: CGSize,
    displays: [DisplayFrame],
    titleBarHeight: CGFloat = 24,
    minimumVisibleTitleBarWidth: CGFloat = 80
) -> CGPoint {
    guard proposed.x.isFinite, proposed.y.isFinite,
          windowSize.width.isFinite, windowSize.height.isFinite,
          windowSize.width > 0, windowSize.height > 0,
          !displays.isEmpty else { return proposed }

    let titleHeight = min(max(titleBarHeight, 0), windowSize.height)
    let titleWidth = min(max(minimumVisibleTitleBarWidth, 0), windowSize.width)

    let usableFrames = displays.compactMap { display -> CGRect? in
        let frame = display.visibleFrame
        guard frame.minX.isFinite, frame.minY.isFinite,
              frame.maxX.isFinite, frame.maxY.isFinite,
              frame.width.isFinite, frame.height.isFinite,
              frame.width > 0, frame.height > 0,
              frame.height >= titleHeight else { return nil }
        return frame
    }

    func isReachable(_ origin: CGPoint) -> Bool {
        let left = origin.x
        let right = origin.x + windowSize.width
        let top = origin.y
        let bottom = origin.y + titleHeight
        guard left.isFinite, right.isFinite, top.isFinite, bottom.isFinite else { return false }

        let yBreaks = Set([top, bottom] + usableFrames.flatMap { frame in
            [frame.minY, frame.maxY].filter { $0 > top && $0 < bottom }
        }).sorted()
        let ySlices: [(CGFloat, CGFloat)] = titleHeight == 0
            ? [(top, top)]
            : Array(zip(yBreaks, yBreaks.dropFirst()))
        var commonCoverage: [ClosedRange<CGFloat>]?
        for (lower, upper) in ySlices {
            let y = (lower + upper) / 2
            let activeFrames = usableFrames.filter { y >= $0.minY && y <= $0.maxY }
                .sorted { $0.minX < $1.minX }
            var coverage: [ClosedRange<CGFloat>] = []
            for frame in activeFrames {
                let start = max(left, frame.minX)
                let end = min(right, frame.maxX)
                guard end > start else { continue }
                if let last = coverage.last, start <= last.upperBound {
                    coverage[coverage.count - 1] = last.lowerBound...max(last.upperBound, end)
                } else {
                    coverage.append(start...end)
                }
            }
            guard !coverage.isEmpty else { return false }
            if let existing = commonCoverage {
                var intersection: [ClosedRange<CGFloat>] = []
                for first in existing {
                    for second in coverage {
                        let lower = max(first.lowerBound, second.lowerBound)
                        let upper = min(first.upperBound, second.upperBound)
                        if lower <= upper { intersection.append(lower...upper) }
                    }
                }
                commonCoverage = intersection
            } else {
                commonCoverage = coverage
            }
        }
        return commonCoverage?.contains { $0.upperBound - $0.lowerBound >= titleWidth } ?? false
    }

    // Work in horizontal slices so vertically offset displays do not turn
    // the empty area between them into reachable desktop space. Within each
    // slice, adjacent displays form one continuous title-bar surface.
    let yBreaks = Set(usableFrames.flatMap { [$0.minY, $0.maxY - titleHeight] }).sorted()
    var validOrigins: [CGRect] = []
    let slices: [(CGFloat, CGFloat)] = yBreaks.count == 1
        ? [(yBreaks[0], yBreaks[0])]
        : Array(zip(yBreaks, yBreaks.dropFirst()))
    for (lower, upper) in slices where lower <= upper {
        let y = (lower + upper) / 2
        let activeFrames = usableFrames.filter {
            y >= $0.minY && y <= $0.maxY - titleHeight
        }.sorted { $0.minX < $1.minX }

        var horizontalSurfaces: [ClosedRange<CGFloat>] = []
        for frame in activeFrames {
            if let last = horizontalSurfaces.last, frame.minX <= last.upperBound {
                horizontalSurfaces[horizontalSurfaces.count - 1] = last.lowerBound...max(last.upperBound, frame.maxX)
            } else {
                horizontalSurfaces.append(frame.minX...frame.maxX)
            }
        }

        for surface in horizontalSurfaces {
            guard surface.upperBound - surface.lowerBound >= titleWidth else { continue }
            let minX = surface.lowerBound - windowSize.width + titleWidth
            let maxX = surface.upperBound - titleWidth
            guard minX <= maxX else { continue }
            validOrigins.append(CGRect(x: minX, y: lower, width: maxX - minX, height: upper - lower))
        }
    }

    guard !validOrigins.isEmpty else { return proposed }
    if isReachable(proposed) { return proposed }

    // Project to the nearest valid rectangle. This is the smallest correction
    // needed at an outer desktop edge or a genuine gap between displays.
    let nearest = validOrigins.min {
        distance(from: proposed, to: $0) < distance(from: proposed, to: $1)
    }!
    return CGPoint(
        x: min(max(proposed.x, nearest.minX), nearest.maxX),
        y: min(max(proposed.y, nearest.minY), nearest.maxY)
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
