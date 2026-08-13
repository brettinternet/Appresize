import Foundation


struct Environment {
    var date: () -> Date = { Date() }
    var defaults: () -> UserDefaults = {
        UserDefaults(suiteName: "cloud.brett.HyperWindow.prefs") ?? .standard
    }
}


var Current = Environment()
