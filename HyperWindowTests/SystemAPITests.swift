import XCTest
import ApplicationServices
@testable import HyperWindow


final class SystemAPITests: XCTestCase {

    func testAccessibilityTrustOptionsUseRequestedBoolean() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String

        let prompted = accessibilityTrustOptions(prompt: true) as NSDictionary
        XCTAssertEqual((prompted[key] as? NSNumber)?.boolValue, true)

        let silent = accessibilityTrustOptions(prompt: false) as NSDictionary
        XCTAssertEqual((silent[key] as? NSNumber)?.boolValue, false)
    }

    func testFrontmostWindowUsesCGOrderAndFiltersUnsupportedEntries() {
        let point = CGPoint(x: 50, y: 50)
        let fixtures = [
            windowInfo(pid: 10, frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
            windowInfo(pid: 11, frame: CGRect(x: 0, y: 0, width: 100, height: 100), layer: 1),
            [kCGWindowOwnerPID as String: NSNumber(value: 12)],
            windowInfo(
                pid: 13,
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                title: "Front"
            ),
            windowInfo(pid: 14, frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        ]

        XCTAssertEqual(
            frontmostWindow(at: point, in: fixtures, excludingPID: 10),
            CGWindowHit(
                ownerPID: 13,
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                title: "Front"
            )
        )
    }

    func testFrontmostWindowReturnsNilWithoutContainingBounds() {
        let fixtures = [
            windowInfo(pid: 10, frame: CGRect(x: 0, y: 0, width: 10, height: 10)),
            [kCGWindowOwnerPID as String: NSNumber(value: 11)]
        ]

        XCTAssertNil(
            frontmostWindow(
                at: CGPoint(x: 50, y: 50),
                in: fixtures,
                excludingPID: 99
            )
        )
    }

    func testAXWindowMatchingPrefersFrameWithinTolerance() {
        let hit = CGWindowHit(
            ownerPID: 10,
            frame: CGRect(x: 100, y: 200, width: 800, height: 600),
            title: "Document"
        )
        let candidates = [
            AXWindowMatchCandidate(
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                title: "Document"
            ),
            AXWindowMatchCandidate(
                frame: CGRect(x: 102, y: 198, width: 798, height: 602),
                title: "Other"
            )
        ]

        XCTAssertEqual(matchingWindowIndex(for: hit, candidates: candidates), 1)
    }

    func testAXWindowMatchingFallsBackToTitle() {
        let hit = CGWindowHit(
            ownerPID: 10,
            frame: CGRect(x: 100, y: 200, width: 800, height: 600),
            title: "Document"
        )
        let candidates = [
            AXWindowMatchCandidate(frame: nil, title: "Other"),
            AXWindowMatchCandidate(frame: nil, title: "Document")
        ]

        XCTAssertEqual(matchingWindowIndex(for: hit, candidates: candidates), 1)
    }

    func testAXWindowMatchingReturnsNilWithoutFrameOrTitleMatch() {
        let hit = CGWindowHit(
            ownerPID: 10,
            frame: CGRect(x: 100, y: 200, width: 800, height: 600),
            title: nil
        )
        let candidates = [
            AXWindowMatchCandidate(
                frame: CGRect(x: 102.1, y: 200, width: 800, height: 600),
                title: "Document"
            ),
            AXWindowMatchCandidate(frame: nil, title: nil)
        ]

        XCTAssertNil(matchingWindowIndex(for: hit, candidates: candidates))
    }

    func testCGMatchAvoidsAccessibilityHitTestOnHappyPath() {
        let point = CGPoint(x: 50, y: 50)
        let fixture = windowInfo(
            pid: getpid() + 1,
            frame: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        let expected = AXUIElementCreateSystemWide()
        var resolvedHit: CGWindowHit?
        var accessibilityHitTestCalls = 0

        let result = AXUIElement.window(
            at: point,
            windowInfoProvider: { [fixture] },
            accessibilityWindowProvider: {
                resolvedHit = $0
                return expected
            },
            accessibilityHitTest: { _ in
                accessibilityHitTestCalls += 1
                return nil
            }
        )

        XCTAssertEqual(resolvedHit?.ownerPID, getpid() + 1)
        XCTAssertEqual(accessibilityHitTestCalls, 0)
        XCTAssertTrue(CFEqual(result, expected))
    }

    private func windowInfo(
        pid: pid_t,
        frame: CGRect,
        layer: Int = 0,
        title: String? = nil
    ) -> CGWindowInfo {
        var info: CGWindowInfo = [
            kCGWindowOwnerPID as String: NSNumber(value: pid),
            kCGWindowLayer as String: NSNumber(value: layer),
            kCGWindowBounds as String: CGRectCreateDictionaryRepresentation(frame)
        ]
        info[kCGWindowName as String] = title
        return info
    }
}
