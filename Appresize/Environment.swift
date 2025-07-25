import Foundation


public struct Environment {
    public var environment = ProcessInfo.processInfo.environment
    public var date: () -> Date = { Date() }
    public var defaults: () -> UserDefaults = {
        UserDefaults(suiteName: "cloud.brett.Appresize.prefs") ?? .standard
    }
}


var Current = Environment()
