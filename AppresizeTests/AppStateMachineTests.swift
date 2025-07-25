import XCTest


class AppStateMachineTests: XCTestCase {

    override func tearDown() {
        Tracker.disable()
    }

    func test_app_launches_successfully() throws {
        // setup
        Current.date = { ReferenceDate }
        let defaults = testUserDefaults()
        let firstLaunched = day(offset: -60, from: ReferenceDate)
        try firstLaunched.save(forKey: .firstLaunched, defaults: defaults)
        Current.defaults = { defaults }

        // MUT
        let app = TestAppDelegate()
        app.applicationDidFinishLaunching()

        // assert
        _ = expectation(for: trackerIsActive, evaluatedWith: nil)
        waitForExpectations(timeout: 2)
        XCTAssert(Tracker.isActive)
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
