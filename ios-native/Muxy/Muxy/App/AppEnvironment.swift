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
    let pairingService: PairingService
    let migrator: LegacyExpoMigrator
    let connectionManager: ConnectionManager

    private(set) var bootstrap: Bootstrap = .loading
    private(set) var devices: [DeviceRecord] = []
    private(set) var settings: SettingsRecord = .default
    private(set) var connectionState: ConnectionState = .idle
    private(set) var activeDeviceID: String?

    private var stateObservationTask: Task<Void, Never>?

    init(
        settingsRepository: SettingsRepository = SettingsRepository(),
        deviceRepository: DeviceRepository? = nil,
        installIdentity: InstallIdentityService = InstallIdentityService(),
        pairingService: PairingService = PairingService(),
        migrator: LegacyExpoMigrator = NoopLegacyExpoMigrator()
    ) {
        self.settingsRepository = settingsRepository
        self.deviceRepository = (try? deviceRepository ?? DeviceRepository()) ?? Self.fallbackRepository()
        self.installIdentity = installIdentity
        self.pairingService = pairingService
        self.migrator = migrator
        let identity = installIdentity
        self.connectionManager = ConnectionManager(
            identityProvider: {
                let deviceID = await identity.ensureDeviceID()
                let token = try await identity.ensureInstallToken()
                let name = await identity.resolveDeviceName()
                return PairingService.Identity(deviceID: deviceID, deviceName: name, token: token)
            }
        )
    }

    func start() async {
        _ = try? await migrator.migrateIfNeeded()
        let loadedSettings = await settingsRepository.load()
        let loadedDevices = (try? await deviceRepository.loadAll()) ?? []
        settings = loadedSettings
        devices = loadedDevices
        bootstrap = loadedSettings.hasOnboarded ? .devices : .onboarding
        observeConnectionState()
    }

    private func observeConnectionState() {
        stateObservationTask?.cancel()
        let manager = connectionManager
        stateObservationTask = Task { [weak self] in
            let stream = await manager.stateStream()
            for await state in stream {
                self?.applyConnectionState(state)
            }
        }
    }

    private func applyConnectionState(_ state: ConnectionState) {
        connectionState = state
        if case .idle = state {
            activeDeviceID = nil
        }
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
        try? await deviceRepository.upsert(record)
        devices = (try? await deviceRepository.loadAll()) ?? devices
    }

    func removeDevice(id: String) async {
        if activeDeviceID == id {
            await connectionManager.disconnect()
        }
        try? await deviceRepository.remove(id: id)
        devices = (try? await deviceRepository.loadAll()) ?? devices
    }

    func pair(host: String, port: Int, label: String?) async -> Result<DeviceRecord, PairingFailureReason> {
        let deviceID = await installIdentity.ensureDeviceID()
        let token: String
        do {
            token = try await installIdentity.ensureInstallToken()
        } catch {
            return .failure(.other(message: "keychain: \(error)"))
        }
        let deviceName = await installIdentity.resolveDeviceName()
        let identity = PairingService.Identity(deviceID: deviceID, deviceName: deviceName, token: token)
        let endpoint = PairingService.Endpoint(host: host, port: port)
        let result = await pairingService.pair(endpoint: endpoint, identity: identity, phase: { _ in })

        switch result {
        case .success(let pairingResult):
            let record = DeviceRecord(
                label: (label?.isEmpty == false ? label : nil) ?? host,
                host: host,
                port: port,
                pairing: pairingResult.pairing
            )
            await upsertDevice(record)
            return .success(record)
        case .failure(let reason):
            return .failure(reason)
        }
    }

    func connect(to record: DeviceRecord) async {
        activeDeviceID = record.id
        try? await deviceRepository.markUsed(id: record.id)
        await connectionManager.connect(to: record)
    }

    func disconnect() async {
        await connectionManager.disconnect()
    }

    func suspend() async {
        await connectionManager.suspend()
    }

    func resume() async {
        await connectionManager.resume()
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
