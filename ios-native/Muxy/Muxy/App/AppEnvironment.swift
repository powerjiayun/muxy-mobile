import Foundation
import MuxyCore
import Observation

@MainActor
@Observable
final class AppEnvironment {
    enum Bootstrap {
        case loading
        case onboarding
        case devices
    }

    let settingsRepository: SettingsRepository
    let deviceRepository: DeviceRepository
    let installIdentity: InstallIdentityService
    let migrator: LegacyExpoMigrator

    private(set) var bootstrap: Bootstrap = .loading
    private(set) var devices: [DeviceRecord] = []
    private(set) var settings: SettingsRecord = .default

    init(
        settingsRepository: SettingsRepository = SettingsRepository(),
        deviceRepository: DeviceRepository? = nil,
        installIdentity: InstallIdentityService = InstallIdentityService(),
        migrator: LegacyExpoMigrator = NoopLegacyExpoMigrator()
    ) {
        self.settingsRepository = settingsRepository
        self.deviceRepository = (try? deviceRepository ?? DeviceRepository()) ?? Self.fallbackRepository()
        self.installIdentity = installIdentity
        self.migrator = migrator
    }

    func start() async {
        _ = try? await migrator.migrateIfNeeded()
        let loadedSettings = await settingsRepository.load()
        let loadedDevices = (try? await deviceRepository.loadAll()) ?? []
        settings = loadedSettings
        devices = loadedDevices
        bootstrap = loadedSettings.hasOnboarded ? .devices : .onboarding
    }

    func markOnboardingComplete() {
        var next = settings
        next.hasOnboarded = true
        updateSettings(next)
        bootstrap = .devices
    }

    func setUseNerdFont(_ value: Bool) {
        var next = settings
        next.useNerdFont = value
        updateSettings(next)
    }

    func setAutoFocusTerminal(_ value: Bool) {
        var next = settings
        next.autoFocusTerminal = value
        updateSettings(next)
    }

    func setDemoMode(_ value: Bool) {
        var next = settings
        next.demoMode = value
        updateSettings(next)
    }

    func upsertDevice(_ record: DeviceRecord) async {
        do {
            try await deviceRepository.upsert(record)
            devices = (try? await deviceRepository.loadAll()) ?? devices
        } catch {
            return
        }
    }

    func removeDevice(id: String) async {
        do {
            try await deviceRepository.remove(id: id)
            devices = (try? await deviceRepository.loadAll()) ?? devices
        } catch {
            return
        }
    }

    private func updateSettings(_ next: SettingsRecord) {
        settings = next
        Task { [settingsRepository, next] in
            await settingsRepository.save(next)
        }
    }

    private static func fallbackRepository() -> DeviceRepository {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("muxy-devices-fallback.json")
        return (try? DeviceRepository(fileURL: tmp))!
    }
}
