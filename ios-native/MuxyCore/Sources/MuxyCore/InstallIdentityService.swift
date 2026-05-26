import Foundation
#if canImport(UIKit)
import UIKit
#endif

public actor InstallIdentityService {
    public enum InstallIdentityError: Error, Equatable {
        case secureRandomFailed(OSStatus)
    }

    private let defaults: UserDefaults
    private let keychain: KeychainStore
    private let deviceIDKey: String
    private let tokenAccount: String

    private var cachedDeviceID: String?
    private var cachedToken: String?

    public init(
        defaults: UserDefaults = .standard,
        keychain: KeychainStore = KeychainStore(service: "com.muxy.app.installIdentity"),
        deviceIDKey: String = "muxy.installDeviceID.v1",
        tokenAccount: String = "installToken"
    ) {
        self.defaults = defaults
        self.keychain = keychain
        self.deviceIDKey = deviceIDKey
        self.tokenAccount = tokenAccount
    }

    public func ensureDeviceID() -> String {
        if let cachedDeviceID { return cachedDeviceID }
        if let existing = defaults.string(forKey: deviceIDKey) {
            cachedDeviceID = existing
            return existing
        }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: deviceIDKey)
        cachedDeviceID = generated
        return generated
    }

    public func ensureInstallToken() throws -> String {
        if let cachedToken { return cachedToken }
        do {
            if let existing = try keychain.read(account: tokenAccount) {
                cachedToken = existing
                return existing
            }
            let generated = try Self.generateToken()
            try keychain.write(account: tokenAccount, value: generated)
            cachedToken = generated
            return generated
        } catch KeychainStore.KeychainError.unexpectedStatus(-34018) {
            let fallbackKey = "muxy.installToken.fallback.v1"
            if let existing = defaults.string(forKey: fallbackKey) {
                cachedToken = existing
                return existing
            }
            let generated = try Self.generateToken()
            defaults.set(generated, forKey: fallbackKey)
            cachedToken = generated
            return generated
        }
    }

    public func resolveDeviceName() -> String {
#if canImport(UIKit)
        let name = UIDevice.current.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "iOS Device" : name
#else
        return "Muxy Device"
#endif
    }

    private static func generateToken() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw InstallIdentityError.secureRandomFailed(status)
        }
        return Data(bytes).base64EncodedString()
    }
}
