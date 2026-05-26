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

    public func findByEndpoint(host: String, port: Int) async throws -> DeviceRecord? {
        _ = try await loadAll()
        return cache.first { $0.host == host && $0.port == port }
    }

    public func upsert(_ record: DeviceRecord) async throws -> DeviceRecord {
        _ = try await loadAll()
        if let idx = cache.firstIndex(where: { $0.id == record.id }) {
            cache[idx] = record
            try await store.save(cache)
            return record
        }
        if let idx = cache.firstIndex(where: { $0.host == record.host && $0.port == record.port }) {
            var merged = record
            merged.id = cache[idx].id
            merged.createdAt = cache[idx].createdAt
            cache[idx] = merged
            try await store.save(cache)
            return merged
        }
        cache.append(record)
        try await store.save(cache)
        return record
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
