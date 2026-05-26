import Foundation
import Testing
@testable import MuxyCore

@Suite("NoopLegacyExpoMigrator")
struct LegacyExpoMigratorTests {
    private func freshKey() -> String { "muxy.tests.migrator.\(UUID().uuidString)" }

    @Test("first run reports didRun=true with zero imports and sets the flag")
    func firstRunSetsFlag() async throws {
        let key = freshKey()
        let migrator = NoopLegacyExpoMigrator(didMigrateKey: key)
        let result = try await migrator.migrateIfNeeded()
        #expect(result == .ranEmpty)
        #expect(UserDefaults.standard.bool(forKey: key) == true)
        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test("subsequent runs are skipped")
    func subsequentRunsAreSkipped() async throws {
        let key = freshKey()
        UserDefaults.standard.set(true, forKey: key)
        let migrator = NoopLegacyExpoMigrator(didMigrateKey: key)
        let result = try await migrator.migrateIfNeeded()
        #expect(result == .skipped)
        UserDefaults.standard.removeObject(forKey: key)
    }
}
