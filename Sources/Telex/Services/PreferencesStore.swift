import Foundation

@MainActor protocol PreferencesStoreProtocol { func load() -> AppPreferences; func save(_ value: AppPreferences) throws }
@MainActor final class PreferencesStore: PreferencesStoreProtocol {
    let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> AppPreferences {
        guard let data = defaults.data(forKey: "Telex.preferences"), var value = try? JSONDecoder().decode(AppPreferences.self, from: data) else { return AppPreferences() }
        value.validate()
        // Click-through is session-only so the panel is recoverable after a crash.
        value.clickThroughEnabled = false
        return value
    }
    func save(_ value: AppPreferences) throws {
        var checked = value
        checked.validate()
        defaults.set(try JSONEncoder().encode(checked), forKey: "Telex.preferences")
    }
}
