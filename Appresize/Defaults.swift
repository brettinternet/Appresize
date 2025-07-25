import Foundation


enum DefaultsKeys: String {
    case firstLaunched
    case moveModifiers
    case resizeModifiers
    case resizeFromNearestCorner
    case showMenuIcon
    case launchAtLogin
}


let DefaultPreferences = [
    DefaultsKeys.moveModifiers.rawValue: Modifiers<Move>.defaultValue,
    DefaultsKeys.resizeModifiers.rawValue: Modifiers<Resize>.defaultValue,
    DefaultsKeys.showMenuIcon.rawValue: NSNumber.init(booleanLiteral: true),
    DefaultsKeys.launchAtLogin.rawValue: NSNumber.init(booleanLiteral: false)
]


protocol Defaultable {
    static var defaultValue: Any { get }
    init?(forKey: DefaultsKeys, defaults: UserDefaults)
    func save(forKey: DefaultsKeys, defaults: UserDefaults) throws
}
