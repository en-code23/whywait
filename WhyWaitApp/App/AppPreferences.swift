import Foundation

final class AppPreferences {
    private enum Key {
        static let lastPlayedMinigameID = "whywait.lastPlayedMinigameID"
        static let settings = "whywait.settings.v1"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastPlayedMinigameID: String? {
        get { defaults.string(forKey: Key.lastPlayedMinigameID) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.lastPlayedMinigameID)
            } else {
                defaults.removeObject(forKey: Key.lastPlayedMinigameID)
            }
        }
    }

    var settings: WhyWaitSettings {
        get {
            guard let data = defaults.data(forKey: Key.settings),
                  let decoded = try? JSONDecoder().decode(WhyWaitSettings.self, from: data) else {
                return WhyWaitSettings()
            }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Key.settings)
        }
    }
}
