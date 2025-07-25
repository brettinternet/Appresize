import Foundation
@testable import Appresize


let ReferenceDate = Date(timeIntervalSince1970: 1234567890)  // 2009-02-13 23:31:30 +0000


func day(offset: Int, from date: Date = Current.date()) -> Date {
    return Calendar.current.date(byAdding: .day, value: offset, to: date)!
}


let yesterday = day(offset: -1)


func testUserDefaults() -> UserDefaults {
    let bundleId = Bundle.main.bundleIdentifier!
    let suiteName = "\(bundleId).tests"
    let prefs = UserDefaults(suiteName: suiteName)!
    prefs.removePersistentDomain(forName: suiteName)
    return prefs
}

