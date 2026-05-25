import Foundation

public actor JSONFileStore<Value: Codable & Sendable> {
    private let url: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    public init(url: URL, fileManager: FileManager = .default) {
        self.url = url
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load() throws -> Value? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { return nil }
        return try decoder.decode(Value.self, from: data)
    }

    public func save(_ value: Value) throws {
        try ensureDirectory()
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    public func delete() throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func ensureDirectory() throws {
        let dir = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}

public enum AppStorageLocations {
    public static func devicesFile(in baseDir: URL? = nil) throws -> URL {
        try applicationSupport(baseDir: baseDir).appendingPathComponent("devices.json")
    }

    private static func applicationSupport(baseDir: URL?) throws -> URL {
        if let baseDir { return baseDir }
        let fm = FileManager.default
        let dir = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return dir.appendingPathComponent("Muxy", isDirectory: true)
    }
}
