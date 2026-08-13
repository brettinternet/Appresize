import Foundation


extension Date: Defaultable {
    init?(forKey key: DefaultsKeys, defaults: UserDefaults) {
        guard let value = defaults.object(forKey: key.rawValue) as? Date else { return nil }
        self = value
    }

    func save(forKey key: DefaultsKeys, defaults: UserDefaults) throws {
        defaults.set(self, forKey: key.rawValue)
    }
}
