import Foundation

public protocol LegacyExpoMigrator: Sendable {
    func migrateIfNeeded() async throws -> LegacyMigrationResult
}

public struct LegacyMigrationResult: Equatable, Sendable {
    public let didRun: Bool
    public let importedDeviceCount: Int

    public init(didRun: Bool, importedDeviceCount: Int) {
        self.didRun = didRun
        self.importedDeviceCount = importedDeviceCount
    }

    public static let skipped = LegacyMigrationResult(didRun: false, importedDeviceCount: 0)
}

public actor NoopLegacyExpoMigrator: LegacyExpoMigrator {
    private let defaults: UserDefaults
    private let didMigrateKey: String

    public init(defaults: UserDefaults = .standard, didMigrateKey: String = "muxy.migration.expoLegacy.v1") {
        self.defaults = defaults
        self.didMigrateKey = didMigrateKey
    }

    public func migrateIfNeeded() async throws -> LegacyMigrationResult {
        if defaults.bool(forKey: didMigrateKey) {
            return .skipped
        }
        defaults.set(true, forKey: didMigrateKey)
        return .skipped
    }
}
