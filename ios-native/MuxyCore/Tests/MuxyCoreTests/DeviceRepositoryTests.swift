import Foundation
import Testing
@testable import MuxyCore

@Suite("DeviceRepository")
struct DeviceRepositoryTests {
    private func tempURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("muxy-tests-\(UUID().uuidString)", isDirectory: true)
        return dir.appendingPathComponent("devices.json")
    }

    @Test("loadAll returns empty when no file exists")
    func loadEmpty() async throws {
        let repo = try DeviceRepository(fileURL: tempURL())
        let all = try await repo.loadAll()
        #expect(all.isEmpty)
    }

    @Test("upsert persists across instances")
    func upsertPersists() async throws {
        let url = tempURL()
        let first = try DeviceRepository(fileURL: url)
        let record = DeviceRecord(label: "Work", host: "10.0.0.5", port: 4865)
        _ = try await first.upsert(record)

        let second = try DeviceRepository(fileURL: url)
        let all = try await second.loadAll()
        #expect(all.count == 1)
        #expect(all.first?.label == "Work")
        #expect(all.first?.host == "10.0.0.5")
    }

    @Test("upsert replaces existing record by id")
    func upsertReplaces() async throws {
        let url = tempURL()
        let repo = try DeviceRepository(fileURL: url)
        let record = DeviceRecord(id: "stable", label: "Old", host: "h", port: 1)
        _ = try await repo.upsert(record)
        var updated = record
        updated.label = "New"
        updated.port = 2
        _ = try await repo.upsert(updated)
        let all = try await repo.loadAll()
        #expect(all.count == 1)
        #expect(all.first?.label == "New")
        #expect(all.first?.port == 2)
    }

    @Test("upsert dedupes by host+port and keeps the existing id")
    func upsertDedupesByEndpoint() async throws {
        let url = tempURL()
        let repo = try DeviceRepository(fileURL: url)
        let first = DeviceRecord(id: "first", label: "Mac", host: "192.168.0.5", port: 4865)
        _ = try await repo.upsert(first)
        let second = DeviceRecord(label: "Mac (renamed)", host: "192.168.0.5", port: 4865)
        let saved = try await repo.upsert(second)
        #expect(saved.id == "first")
        let all = try await repo.loadAll()
        #expect(all.count == 1)
        #expect(all.first?.label == "Mac (renamed)")
    }

    @Test("findByEndpoint returns the matching record")
    func findByEndpoint() async throws {
        let url = tempURL()
        let repo = try DeviceRepository(fileURL: url)
        _ = try await repo.upsert(DeviceRecord(id: "a", label: "A", host: "h", port: 1))
        _ = try await repo.upsert(DeviceRecord(id: "b", label: "B", host: "h", port: 2))
        let found = try await repo.findByEndpoint(host: "h", port: 2)
        #expect(found?.id == "b")
        let missing = try await repo.findByEndpoint(host: "h", port: 9)
        #expect(missing == nil)
    }

    @Test("remove drops the matching record")
    func removeDrops() async throws {
        let url = tempURL()
        let repo = try DeviceRepository(fileURL: url)
        let a = DeviceRecord(id: "a", label: "A", host: "h", port: 1)
        let b = DeviceRecord(id: "b", label: "B", host: "h", port: 2)
        _ = try await repo.upsert(a)
        _ = try await repo.upsert(b)
        try await repo.remove(id: "a")
        let all = try await repo.loadAll()
        #expect(all.map(\.id) == ["b"])
    }

    @Test("markUsed updates lastUsedAt")
    func markUsedUpdates() async throws {
        let url = tempURL()
        let repo = try DeviceRepository(fileURL: url)
        _ = try await repo.upsert(DeviceRecord(id: "x", label: "X", host: "h", port: 1))
        let now = Date()
        try await repo.markUsed(id: "x", at: now)
        let all = try await repo.loadAll()
        #expect(all.first?.lastUsedAt == now)
    }
}
