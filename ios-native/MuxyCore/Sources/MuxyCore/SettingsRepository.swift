import Foundation
import OSLog

public actor SettingsRepository {
    private let defaults: UserDefaults
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger: Logger

    public init(defaults: UserDefaults = .standard, key: String = "muxy.settings.v1") {
        self.defaults = defaults
        self.key = key
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.logger = Logger(subsystem: "com.muxy.app", category: "SettingsRepository")
    }

    public func load() -> SettingsRecord {
        guard let data = defaults.data(forKey: key),
              let decoded = try? decoder.decode(SettingsRecord.self, from: data) else {
            return .default
        }
        return decoded
    }

    public func save(_ record: SettingsRecord) throws {
        let data = try encoder.encode(record)
        defaults.set(data, forKey: key)
    }
}
