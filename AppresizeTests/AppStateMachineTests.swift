import XCTest
@testable import Appresize


class AppStateMachineTests: XCTestCase {

    override func tearDown() {
        Tracker.disable()
    }

    // DISABLED: This test triggers accessibility permission dialogs that hang CI
    // TODO: Re-enable when we have a proper test environment setup
    func DISABLED_test_app_launches_successfully() throws {
        // setup
        Current.date = { ReferenceDate }
        let defaults = testUserDefaults()
        let firstLaunched = day(offset: -60, from: ReferenceDate)
        try firstLaunched.save(forKey: .firstLaunched, defaults: defaults)
        Current.defaults = { defaults }

        // MUT - Create app and state machine but don't trigger full activation
        let app = TestAppDelegate()
        
        // Test initial state
        XCTAssertEqual(app.stateMachine.state, .launching)
        
        // Test manual state transition (without full activation that triggers permissions)
        app.stateMachine.state = .validatingState
        XCTAssertEqual(app.stateMachine.state, .validatingState)
        
        // Verify that transitions were recorded
        XCTAssertEqual(app.transitions.count, 1)
        XCTAssertEqual(app.transitions[0].from, .launching)
        XCTAssertEqual(app.transitions[0].to, .validatingState)
    }
}


class AppDelegateLaunchTests: XCTestCase {

    func test_login_item_open_event_is_detected() {
        let event = openApplicationEvent()
        event.setParam(
            NSAppleEventDescriptor(enumCode: keyAELaunchedAsLogInItem),
            forKeyword: keyAEPropData
        )

        XCTAssertTrue(isLoginItemLaunch(event))
    }

    func test_manual_open_event_is_not_detected_as_login_item() {
        XCTAssertFalse(isLoginItemLaunch(openApplicationEvent()))
    }

    func test_missing_launch_event_is_not_detected_as_login_item() {
        XCTAssertFalse(isLoginItemLaunch(nil))
    }

    private func openApplicationEvent() -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEOpenApplication),
            targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
    }
}


// MARK:- Helpers


let trackerIsActive = NSPredicate { (_, _) in
    Tracker.isActive
}


let trackerIsNotActive = NSPredicate { (_, _) in
    !Tracker.isActive
}


func testUserDefaults(firstLaunched: Date?) throws -> UserDefaults {
    let def = testUserDefaults()
    if let firstLaunched = firstLaunched {
        try firstLaunched.save(forKey: .firstLaunched, defaults: def)
    }
    return def
}


class TestAppDelegate {
    var stateMachine = AppStateMachine()

    var transitions = [(from: AppStateMachine.State, to: AppStateMachine.State)]()

    func applicationDidFinishLaunching() {
        stateMachine.delegate = self
        XCTAssertEqual(stateMachine.state, .launching)
        XCTAssert(!Tracker.isActive)
        stateMachine.state = .validatingState
    }
}

extension TestAppDelegate: DidTransitionDelegate {
    func didTransition(from: AppStateMachine.State, to: AppStateMachine.State) {
        transitions.append((from, to))
    }
}
