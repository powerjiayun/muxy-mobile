import Foundation
import Testing
@testable import MuxyCore

@Suite("KeychainStore")
struct KeychainStoreTests {
    private func freshStore() -> KeychainStore {
        KeychainStore(service: "com.muxy.tests.\(UUID().uuidString)")
    }

    @Test("write then read returns the value")
    func writeRead() throws {
        let store = freshStore()
        try store.write(account: "token", value: "hello")
        #expect(try store.read(account: "token") == "hello")
        try store.delete(account: "token")
    }

    @Test("write twice updates the value")
    func writeOverwrites() throws {
        let store = freshStore()
        try store.write(account: "token", value: "v1")
        try store.write(account: "token", value: "v2")
        #expect(try store.read(account: "token") == "v2")
        try store.delete(account: "token")
    }

    @Test("read missing account returns nil")
    func readMissing() throws {
        let store = freshStore()
        #expect(try store.read(account: "missing") == nil)
    }

    @Test("delete of missing account is a no-op")
    func deleteMissing() throws {
        let store = freshStore()
        try store.delete(account: "missing")
    }
}
