import XCTest
@testable import Appresize


class AppStateMachineTests: XCTestCase {

    override func tearDown() {
        Tracker.disable()
    }

}


class AppDelegateLaunchTests: XCTestCase {

    func test_manual_first_launch_presents_settings_but_login_launch_stays_silent() {
        XCTAssertTrue(AppDelegate.shouldPresentFirstLaunchSettings(isFirstLaunch: true, launchedAsLoginItem: false))
        XCTAssertFalse(AppDelegate.shouldPresentFirstLaunchSettings(isFirstLaunch: true, launchedAsLoginItem: true))
        XCTAssertFalse(AppDelegate.shouldPresentFirstLaunchSettings(isFirstLaunch: false, launchedAsLoginItem: false))
    }

    func test_login_launch_suppresses_permission_alerts() {
        XCTAssertTrue(AppDelegate.shouldPresentPermissionAlert(launchedAsLoginItem: false))
        XCTAssertFalse(AppDelegate.shouldPresentPermissionAlert(launchedAsLoginItem: true))
    }

    func test_statusPresentationRequires_tracker_permission_and_activated_state() {
        XCTAssertTrue(AppDelegate.statusIsActive(state: .activated, trackerIsActive: true, isTrusted: true))
        XCTAssertFalse(AppDelegate.statusIsActive(state: .activated, trackerIsActive: false, isTrusted: true))
        XCTAssertFalse(AppDelegate.statusIsActive(state: .activated, trackerIsActive: true, isTrusted: false))
        XCTAssertFalse(AppDelegate.statusIsActive(state: .deactivated, trackerIsActive: true, isTrusted: true))
    }

    func test_xctest_host_does_not_start_runtime_services() {
        XCTAssertTrue(AppDelegate.isUnitTestHost(environment: ["XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"]))
        XCTAssertFalse(AppDelegate.isUnitTestHost(environment: [:]))
    }

    func test_enabled_toggle_deactivates_active_tracker() {
        let app = AppStateMachine(initialState: .activated)
        app.toggleEnabled()
        XCTAssertEqual(app.state, .deactivated)
        XCTAssertFalse(Tracker.isActive)
    }

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
