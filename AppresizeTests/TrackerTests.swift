import XCTest
@testable import Appresize

final class TrackerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var now: CFAbsoluteTime = 0

    override func setUp() {
        super.setUp()
        defaults = testUserDefaults()
        registerDefaultPreferences(in: defaults)
        defaults.set(Modifiers<Move>.control.rawValue, forKey: DefaultsKeys.moveModifiers.rawValue)
        defaults.set(Modifiers<Resize>.alt.rawValue, forKey: DefaultsKeys.resizeModifiers.rawValue)
        defaults.set(false, forKey: DefaultsKeys.resizeFromNearestCorner.rawValue)
        Current.defaults = { [unowned self] in self.defaults }
        now = 0
    }

    override func tearDown() {
        Tracker.disable()
        Current.defaults = { UserDefaults(suiteName: "cloud.brett.Appresize.prefs") ?? .standard }
        super.tearDown()
    }

    func testHandledEventsRefreshInactivityTimeout() throws {
        let window = FakeWindow()
        let tracker = try makeTracker(window: window)

        XCTAssertTrue(tracker.handleEvent(event(flags: .maskControl), type: .mouseMoved))
        now = 4
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskControl, dx: 1), type: .mouseMoved))
        now = 8
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskControl, dx: 1), type: .mouseMoved))
        XCTAssertEqual(window.origin.x, 2)
    }

    func testIdleToMoveAndResizeTransitions() throws {
        let window = FakeWindow()
        let tracker = try makeTracker(window: window)

        XCTAssertTrue(tracker.handleEvent(event(flags: .maskControl), type: .mouseMoved))
        now = 1
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskAlternate), type: .mouseMoved))
        now = 2
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskControl), type: .mouseMoved))
        XCTAssertEqual(window.origin, .zero)
    }

    func testModifierReleaseEndsOperationWithoutConsumingMouseUp() throws {
        let tracker = try makeTracker(window: FakeWindow())
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskControl), type: .mouseMoved))
        XCTAssertTrue(tracker.handleEvent(event(flags: []), type: .mouseMoved))
        XCTAssertFalse(tracker.handleEvent(event(flags: []), type: .leftMouseUp))
    }

    func testTimeoutResetsOperationAndPassesNextEventThrough() throws {
        let tracker = try makeTracker(window: FakeWindow())
        now = 1
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskControl), type: .mouseMoved))
        now = 7
        XCTAssertFalse(tracker.handleEvent(event(flags: .maskControl), type: .mouseMoved))
        now = 8
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskControl), type: .mouseMoved))
    }

    func testDragOnlyEndsOnlyForMatchingMouseUp() throws {
        defaults.set(true, forKey: DefaultsKeys.requireDragToActivate.rawValue)
        let tracker = try makeTracker(window: FakeWindow())
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskControl, button: 1), type: .leftMouseDragged))
        XCTAssertFalse(tracker.handleEvent(event(flags: [], button: 2), type: .leftMouseUp))
        XCTAssertFalse(tracker.handleEvent(event(flags: [], button: 1), type: .leftMouseUp))
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskControl, button: 1), type: .leftMouseDragged))
    }

    func testNonSettableWindowDoesNotConsumeActivation() throws {
        let window = FakeWindow()
        window.canSetOrigin = false
        let tracker = try makeTracker(window: window)

        XCTAssertFalse(tracker.handleEvent(event(flags: .maskControl), type: .mouseMoved))
        XCTAssertEqual(window.origin, .zero)
    }

    func testNonSettableResizeDoesNotConsumeActivation() throws {
        let window = FakeWindow()
        window.canSetSize = false
        let tracker = try makeTracker(window: window)

        XCTAssertFalse(tracker.handleEvent(event(flags: .maskAlternate), type: .mouseMoved))
        XCTAssertEqual(window.size.width, 100)
    }

    func testFailedWriteStopsTrackingImmediately() throws {
        let window = FakeWindow()
        window.failOriginWrite = true
        let tracker = try makeTracker(window: window)

        XCTAssertTrue(tracker.handleEvent(event(flags: .maskControl), type: .mouseMoved))
        now = 1
        XCTAssertFalse(tracker.handleEvent(event(flags: .maskControl, dx: 1), type: .mouseMoved))
        now = 2
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskControl), type: .mouseMoved))
    }

    func testResizeReadsBackClampedSizeBeforeReversing() throws {
        let window = FakeWindow()
        window.minimumWidth = 50
        let tracker = try makeTracker(window: window)

        XCTAssertTrue(tracker.handleEvent(event(flags: .maskAlternate), type: .mouseMoved))
        now = 1
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskAlternate, dx: -90), type: .mouseMoved))
        XCTAssertEqual(window.size.width, 50)
        now = 2
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskAlternate, dx: 10), type: .mouseMoved))
        XCTAssertEqual(window.size.width, 60)
    }

    func testResizeAccumulatesDeltasInsideFilterInterval() throws {
        let window = FakeWindow()
        let tracker = try makeTracker(window: window)

        XCTAssertTrue(tracker.handleEvent(event(flags: .maskAlternate), type: .mouseMoved))
        now = 0.005
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskAlternate, dx: 1), type: .mouseMoved))
        now = 0.010
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskAlternate, dx: 2), type: .mouseMoved))
        now = 0.030
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskAlternate, dx: 3), type: .mouseMoved))

        XCTAssertEqual(window.size.width, 106)
    }

    func testMoveCursorIsRestoredWhenModifiersAreReleased() throws {
        let window = FakeWindow()
        var selected: [Tracker.CursorKind] = []
        var cursorSets = 0
        let tracker = try makeTracker(
            window: window,
            cursorSet: { _ in cursorSets += 1 },
            cursorFor: { selected.append($0); return NSCursor.arrow }
        )

        XCTAssertTrue(tracker.handleEvent(event(flags: .maskControl), type: .mouseMoved))
        XCTAssertTrue(tracker.handleEvent(event(flags: []), type: .mouseMoved))
        XCTAssertEqual(selected, [.move])
        XCTAssertEqual(cursorSets, 2)
    }

    func testPermissionLossRestoresCursorAndRejectsEvent() throws {
        let window = FakeWindow()
        var trusted = true
        var cursorSets = 0
        let tracker = try makeTracker(
            window: window,
            trusted: { trusted },
            cursorSet: { _ in cursorSets += 1 }
        )

        XCTAssertTrue(tracker.handleEvent(event(flags: .maskControl), type: .mouseMoved))
        trusted = false
        XCTAssertFalse(tracker.handleEvent(event(flags: .maskControl, dx: 1), type: .mouseMoved))
        XCTAssertEqual(cursorSets, 2)
    }

    func testResizeOvershootClampsToNativeMinimumAndReversesImmediately() throws {
        let window = FakeWindow()
        window.minimumWidth = 50
        var cursorSets = 0
        let tracker = try makeTracker(
            window: window,
            cursorSet: { _ in cursorSets += 1 }
        )

        XCTAssertTrue(tracker.handleEvent(event(flags: .maskAlternate), type: .mouseMoved))
        now = 1
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskAlternate, dx: -150), type: .mouseMoved))
        XCTAssertEqual(window.size.width, 50)
        now = 2
        XCTAssertTrue(tracker.handleEvent(event(flags: .maskAlternate, dx: 10), type: .mouseMoved))
        XCTAssertEqual(window.size.width, 60)
        XCTAssertEqual(cursorSets, 1)
    }

    func testMoveKeepsTitleBarVisibleAcrossDisplays() throws {
        let window = FakeWindow()
        let displays = [
            DisplayFrame(visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 800)),
            DisplayFrame(visibleFrame: CGRect(x: 1000, y: 0, width: 1000, height: 800))
        ]
        let tracker = try makeTracker(window: window, displays: { displays })

        XCTAssertTrue(tracker.handleEvent(event(flags: .maskControl), type: .mouseMoved))
        now = 1
        // Coordinates are Accessibility points (top-left origin, Y down). The
        // proposed origin is below the secondary display and is clamped so its
        // title bar remains reachable.
        XCTAssertTrue(tracker.handleEvent(
            event(flags: .maskControl, dx: 1_900, dy: 1_000, location: CGPoint(x: 1_900, y: 1_000)),
            type: .mouseMoved
        ))
        XCTAssertEqual(window.origin, CGPoint(x: 1_900, y: 776))
    }

    func testSmallMoveDeltasCanCrossDisplayBoundary() throws {
        let window = FakeWindow()
        window.origin = CGPoint(x: 920, y: 100)
        let displays = [
            DisplayFrame(visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 800)),
            DisplayFrame(visibleFrame: CGRect(x: 1000, y: 0, width: 1000, height: 800))
        ]
        let tracker = try makeTracker(window: window, displays: { displays })

        XCTAssertTrue(tracker.handleEvent(
            event(flags: .maskControl, location: CGPoint(x: 990, y: 100)),
            type: .mouseMoved
        ))
        now = 1
        XCTAssertTrue(tracker.handleEvent(
            event(flags: .maskControl, dx: 10, location: CGPoint(x: 1_001, y: 100)),
            type: .mouseMoved
        ))
        XCTAssertEqual(window.origin.x, 980)
    }

    func testClampedTopLeftResizeKeepsOppositeEdgesFixed() throws {
        defaults.set(true, forKey: DefaultsKeys.resizeFromNearestCorner.rawValue)
        let window = FakeWindow()
        window.origin = CGPoint(x: 100, y: 100)
        window.minimumWidth = 50
        window.minimumHeight = 40
        let tracker = try makeTracker(window: window)

        XCTAssertTrue(tracker.handleEvent(
            event(flags: .maskAlternate, location: CGPoint(x: 100, y: 100)),
            type: .mouseMoved
        ))
        now = 1
        XCTAssertTrue(tracker.handleEvent(
            event(flags: .maskAlternate, dx: 90, dy: 90, location: CGPoint(x: 190, y: 190)),
            type: .mouseMoved
        ))

        XCTAssertEqual(window.size, CGSize(width: 50, height: 40))
        XCTAssertEqual(window.origin, CGPoint(x: 150, y: 160))
        XCTAssertEqual(window.origin.x + window.size.width, 200)
        XCTAssertEqual(window.origin.y + window.size.height, 200)
    }

    func testFailedResizeWriteDoesNotMoveOrigin() throws {
        defaults.set(true, forKey: DefaultsKeys.resizeFromNearestCorner.rawValue)
        let window = FakeWindow()
        window.origin = CGPoint(x: 100, y: 100)
        window.failSizeWrite = true
        let tracker = try makeTracker(window: window)

        XCTAssertTrue(tracker.handleEvent(
            event(flags: .maskAlternate, location: CGPoint(x: 100, y: 100)),
            type: .mouseMoved
        ))
        now = 1
        XCTAssertFalse(tracker.handleEvent(
            event(flags: .maskAlternate, dx: -10, dy: -10, location: CGPoint(x: 90, y: 90)),
            type: .mouseMoved
        ))
        XCTAssertEqual(window.origin, CGPoint(x: 100, y: 100))
    }

    func testAppKitDisplayFramesConvertToAccessibilityCoordinates() {
        let primary = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let appKitFrames = [
            primary,
            CGRect(x: 0, y: 800, width: 1000, height: 600),
            CGRect(x: 1000, y: -400, width: 800, height: 400)
        ]

        let converted = accessibilityDisplayFrames(
            appKitVisibleFrames: appKitFrames,
            primaryFrame: primary
        ).map(\.visibleFrame)

        XCTAssertEqual(converted[0], CGRect(x: 0, y: 0, width: 1000, height: 800))
        XCTAssertEqual(converted[1], CGRect(x: 0, y: -600, width: 1000, height: 600))
        XCTAssertEqual(converted[2], CGRect(x: 1000, y: 800, width: 800, height: 400))
    }

    func testConstrainedOriginLeavesInvalidGeometryUnchanged() {
        let proposed = CGPoint(x: 10, y: 20)
        let displays = [DisplayFrame(visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 800))]
        XCTAssertEqual(constrainedOrigin(proposed: proposed, windowSize: CGSize(width: CGFloat.nan, height: 10), displays: displays), proposed)
        XCTAssertEqual(constrainedOrigin(proposed: proposed, windowSize: CGSize(width: 0, height: 10), displays: displays), proposed)
    }

    func testIdleMouseEventsDoNotQueryAccessibilityTrust() throws {
        var trustChecks = 0
        let tracker = try makeTracker(window: FakeWindow(), trusted: {
            trustChecks += 1
            return true
        })

        XCTAssertFalse(tracker.handleEvent(event(flags: []), type: .mouseMoved))
        XCTAssertFalse(tracker.handleEvent(event(flags: .maskShift), type: .mouseMoved))
        XCTAssertEqual(trustChecks, 0)
    }

    func testTapDisabledEventChecksPermissionAndPassesThrough() throws {
        var trusted = true
        var trustChecks = 0
        let tracker = try makeTracker(window: FakeWindow(), trusted: {
            trustChecks += 1
            return trusted
        })

        XCTAssertFalse(tracker.handleEvent(event(flags: []), type: .tapDisabledByTimeout))
        trusted = false
        XCTAssertFalse(tracker.handleEvent(event(flags: []), type: .tapDisabledByTimeout))
        XCTAssertEqual(trustChecks, 2)
    }

    private func makeTracker(
        window: FakeWindow,
        trusted: @escaping () -> Bool = { true },
        displays: @escaping () -> [DisplayFrame] = { [] },
        cursorSet: @escaping (NSCursor) -> Void = { _ in },
        cursorFor: @escaping (Tracker.CursorKind) -> NSCursor = { _ in NSCursor.arrow }
    ) throws -> Tracker {
        try Tracker(dependencies: .init(
            trusted: trusted,
            windowAt: { _ in window.trackingWindow },
            now: { self.now },
            displays: displays,
            cursorCurrent: { NSCursor.arrow },
            cursorSet: cursorSet,
            cursorFor: cursorFor,
            installEventTap: false
        ))
    }

    private func event(
        flags: CGEventFlags,
        dx: Int32 = 0,
        dy: Int32 = 0,
        button: Int64 = 0,
        location: CGPoint = .zero
    ) -> CGEvent {
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: location,
            mouseButton: .left
        )!
        event.flags = flags
        event.setIntegerValueField(.mouseEventButtonNumber, value: button)
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(dx))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(dy))
        return event
    }
}

private final class FakeWindow {
    var origin = CGPoint.zero
    var size = CGSize(width: 100, height: 100)
    var canSetOrigin = true
    var canSetSize = true
    var failOriginWrite = false
    var failSizeWrite = false
    var minimumWidth: CGFloat = 1
    var minimumHeight: CGFloat = 1

    lazy var trackingWindow = TrackingWindow(
        origin: { [unowned self] in self.origin },
        size: { [unowned self] in self.size },
        canSetOrigin: { [unowned self] in self.canSetOrigin },
        canSetSize: { [unowned self] in self.canSetSize },
        setOrigin: { [unowned self] value in
            guard !self.failOriginWrite else { return false }
            self.origin = value
            return true
        },
        setSize: { [unowned self] value in
            guard !self.failSizeWrite else { return false }
            self.size = CGSize(
                width: max(self.minimumWidth, value.width),
                height: max(self.minimumHeight, value.height)
            )
            return true
        }
    )
}
