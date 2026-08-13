import Foundation
@testable import HyperWindow

func testUserDefaults() -> UserDefaults {
    let bundleId = Bundle.main.bundleIdentifier!
    let suiteName = "\(bundleId).tests"
    let prefs = UserDefaults(suiteName: suiteName)!
    prefs.removePersistentDomain(forName: suiteName)
    return prefs
}
