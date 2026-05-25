import Foundation
import Testing
@testable import MuxyCore

@Suite("InstallIdentityService")
struct InstallIdentityServiceTests {
    private func freshKey() -> String { "muxy.tests.installIdentity.\(UUID().uuidString)" }
    private func freshKeychain() -> KeychainStore {
        KeychainStore(service: "com.muxy.tests.identity.\(UUID().uuidString)")
    }

    @Test("ensureDeviceID is stable across instances sharing the same UserDefaults key")
    func deviceIDStable() async {
        let key = freshKey()
        let first = InstallIdentityService(keychain: freshKeychain(), deviceIDKey: key)
        let id1 = await first.ensureDeviceID()
        let second = InstallIdentityService(keychain: freshKeychain(), deviceIDKey: key)
        let id2 = await second.ensureDeviceID()
        #expect(id1 == id2)
        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test("ensureInstallToken is stable across instances sharing the same keychain service")
    func tokenStable() async throws {
        let keychain = freshKeychain()
        let first = InstallIdentityService(keychain: keychain, deviceIDKey: freshKey())
        let token1 = try await first.ensureInstallToken()
        let second = InstallIdentityService(keychain: keychain, deviceIDKey: freshKey())
        let token2 = try await second.ensureInstallToken()
        #expect(token1 == token2)
        try keychain.delete(account: "installToken")
    }
}
