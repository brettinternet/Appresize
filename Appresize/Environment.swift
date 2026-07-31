import Foundation


struct Environment {
    var date: () -> Date = { Date() }
    var defaults: () -> UserDefaults = {
        UserDefaults(suiteName: "cloud.brett.Appresize.prefs") ?? .standard
    }
}


var Current = Environment()
