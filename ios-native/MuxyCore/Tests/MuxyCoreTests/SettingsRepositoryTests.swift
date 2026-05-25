import Foundation
import Testing
@testable import MuxyCore

@Suite("SettingsRepository")
struct SettingsRepositoryTests {
    private func freshKey() -> String { "muxy.tests.settings.\(UUID().uuidString)" }

    @Test("load returns default when nothing saved")
    func loadDefault() async {
        let repo = SettingsRepository(key: freshKey())
        let value = await repo.load()
        #expect(value == .default)
    }

    @Test("save then load round-trips")
    func roundTrips() async {
        let key = freshKey()
        let repo = SettingsRepository(key: key)
        let saved = SettingsRecord(hasOnboarded: true, useNerdFont: true, autoFocusTerminal: false, demoMode: true)
        await repo.save(saved)

        let reloaded = await SettingsRepository(key: key).load()
        #expect(reloaded == saved)

        UserDefaults.standard.removeObject(forKey: key)
    }
}
