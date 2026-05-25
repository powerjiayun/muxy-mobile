import Foundation

public actor DeviceRepository {
    private let store: JSONFileStore<[DeviceRecord]>
    private var cache: [DeviceRecord] = []
    private var loaded = false

    public init(fileURL: URL? = nil) throws {
        let url = try fileURL ?? AppStorageLocations.devicesFile()
        self.store = JSONFileStore(url: url)
    }

    public func loadAll() async throws -> [DeviceRecord] {
        if !loaded {
            cache = (try await store.load()) ?? []
            loaded = true
        }
        return cache
    }

    public func upsert(_ record: DeviceRecord) async throws {
        _ = try await loadAll()
        if let idx = cache.firstIndex(where: { $0.id == record.id }) {
            cache[idx] = record
        } else {
            cache.append(record)
        }
        try await store.save(cache)
    }

    public func remove(id: String) async throws {
        _ = try await loadAll()
        cache.removeAll { $0.id == id }
        try await store.save(cache)
    }

    public func markUsed(id: String, at date: Date = Date()) async throws {
        _ = try await loadAll()
        guard let idx = cache.firstIndex(where: { $0.id == id }) else { return }
        cache[idx].lastUsedAt = date
        try await store.save(cache)
    }

    public func replaceAll(_ records: [DeviceRecord]) async throws {
        cache = records
        loaded = true
        try await store.save(cache)
    }
}
