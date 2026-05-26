import Foundation
import MuxyCore
import MuxyProtocol
import Observation
import OSLog

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
    let discoveryService: DiscoveryService

    private(set) var bootstrap: Bootstrap = .loading
    private(set) var devices: [DeviceRecord] = []
    private(set) var settings: SettingsRecord = .default
    private(set) var connectionState: ConnectionState = .idle
    private(set) var activeDeviceID: String?
    private(set) var discoveryState: DiscoveryUpdate = .searching
    private(set) var projectsState: ProjectsUpdate = .loading
    private(set) var projectLogos: [String: Data] = [:]
    private(set) var workspaceState: WorkspaceUpdate = .loading
    private(set) var activeWorkspaceProjectID: String?
    private(set) var terminalTheme: MuxyTerminalTheme = .default
    private(set) var localDeviceID: String = ""
    var lastConnectError: String?

    private var stateObservationTask: Task<Void, Never>?
    private var discoveryObservationTask: Task<Void, Never>?
    private var projectsObservationTask: Task<Void, Never>?
    private var projectsService: ProjectsService?
    private var workspaceObservationTask: Task<Void, Never>?
    private var workspaceService: WorkspaceService?
    private var themeObservationTask: Task<Void, Never>?
    private var pendingLogoRequests: Set<String> = []
    private let logger = Logger(subsystem: "com.muxy.app", category: "AppEnvironment")

    init(
        settingsRepository: SettingsRepository = SettingsRepository(),
        deviceRepository: DeviceRepository? = nil,
        installIdentity: InstallIdentityService = InstallIdentityService(),
        pairingService: PairingService = PairingService(),
        migrator: LegacyExpoMigrator = NoopLegacyExpoMigrator(),
        discoveryService: DiscoveryService = DiscoveryService()
    ) {
        self.settingsRepository = settingsRepository
        self.deviceRepository = deviceRepository ?? (try! DeviceRepository())
        self.installIdentity = installIdentity
        self.pairingService = pairingService
        self.migrator = migrator
        self.discoveryService = discoveryService
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
        localDeviceID = await installIdentity.ensureDeviceID()
        bootstrap = loadedSettings.hasOnboarded ? .devices : .onboarding
        observeConnectionState()
        observeDiscovery()
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

    private func observeDiscovery() {
        discoveryObservationTask?.cancel()
        let service = discoveryService
        discoveryObservationTask = Task { [weak self] in
            let stream = await service.stream()
            for await update in stream {
                await self?.applyDiscoveryUpdate(update)
            }
        }
    }

    private func applyConnectionState(_ state: ConnectionState) {
        connectionState = state
        switch state {
        case .idle:
            activeDeviceID = nil
            stopProjects()
            stopWorkspace()
            stopThemeObservation()
        case .connected:
            lastConnectError = nil
            if let deviceID = activeDeviceID {
                Task { await self.setNeedsRepair(deviceID: deviceID, value: false) }
            }
            startProjects()
            startThemeObservation()
        case .connecting, .authenticating, .reconnecting, .suspended:
            lastConnectError = nil
            stopProjects()
            stopWorkspace()
            stopThemeObservation()
        case .failed(let reason):
            handleFailure(reason)
            stopProjects()
            stopWorkspace()
            stopThemeObservation()
        }
    }

    private func startThemeObservation() {
        stopThemeObservation()
        let activeDevice = devices.first { $0.id == activeDeviceID }
        terminalTheme = MuxyTerminalTheme.from(pairing: activeDevice?.pairing)
        let manager = connectionManager
        themeObservationTask = Task { [weak self] in
            guard let client = await manager.activeClientHandle() else { return }
            let subscribeParams = AnyTypedValue(
                type: "subscribe",
                value: .object(["events": .array([.string(EventName.themeChanged.rawValue)])])
            )
            _ = try? await client.send(method: .subscribe, params: subscribeParams)
            let stream = await client.events()
            for await event in stream {
                if Task.isCancelled { return }
                guard event.payload.event == EventName.themeChanged.rawValue,
                      let value = event.payload.data?.value else { continue }
                await self?.applyThemeChange(value)
            }
        }
    }

    private func stopThemeObservation() {
        themeObservationTask?.cancel()
        themeObservationTask = nil
    }

    private func applyThemeChange(_ value: AnyCodableValue) {
        do {
            let data = try JSONEncoder().encode(AnyCodable(value))
            let change = try JSONDecoder().decode(ThemeChange.self, from: data)
            terminalTheme = MuxyTerminalTheme.from(change: change, previous: terminalTheme)
        } catch {
            logger.error("themeChanged decode failed: \(error)")
        }
    }

    private func startProjects() {
        stopProjects()
        let manager = connectionManager
        projectsObservationTask = Task { [weak self] in
            guard let client = await manager.activeClientHandle() else { return }
            let service = ProjectsService(client: client)
            self?.assign(service: service)
            let stream = await service.stream()
            for await update in stream {
                self?.projectsState = update
            }
        }
    }

    private func assign(service: ProjectsService) {
        projectsService = service
    }

    private func stopProjects() {
        projectsObservationTask?.cancel()
        projectsObservationTask = nil
        let service = projectsService
        projectsService = nil
        projectsState = .loading
        projectLogos.removeAll()
        pendingLogoRequests.removeAll()
        if let service {
            Task { await service.stop() }
        }
    }

    func refreshProjects() async {
        guard let service = projectsService else { return }
        await service.refresh()
    }

    func requestLogo(projectID: String) {
        guard projectLogos[projectID] == nil,
              !pendingLogoRequests.contains(projectID),
              let service = projectsService else { return }
        pendingLogoRequests.insert(projectID)
        Task { [weak self] in
            let data = await service.loadLogo(projectID: projectID)
            self?.applyLogo(projectID: projectID, data: data)
        }
    }

    private func applyLogo(projectID: String, data: Data?) {
        pendingLogoRequests.remove(projectID)
        if let data {
            projectLogos[projectID] = data
        }
    }

    func startWorkspace(projectID: String) {
        if activeWorkspaceProjectID == projectID, workspaceService != nil { return }
        stopWorkspace()
        activeWorkspaceProjectID = projectID
        let manager = connectionManager
        workspaceObservationTask = Task { [weak self] in
            guard let client = await manager.activeClientHandle() else { return }
            let service = WorkspaceService(client: client, projectID: projectID)
            self?.assign(workspaceService: service)
            let stream = await service.stream()
            for await update in stream {
                self?.workspaceState = update
            }
        }
    }

    func stopWorkspace() {
        workspaceObservationTask?.cancel()
        workspaceObservationTask = nil
        let service = workspaceService
        workspaceService = nil
        workspaceState = .loading
        activeWorkspaceProjectID = nil
        if let service {
            Task { await service.stop() }
        }
    }

    private func assign(workspaceService: WorkspaceService) {
        self.workspaceService = workspaceService
    }

    func refreshWorkspace() async {
        guard let service = workspaceService else { return }
        await service.refresh()
    }

    func createTerminalTab(areaID: String?) async {
        guard let service = workspaceService else { return }
        do {
            try await service.createTerminalTab(areaID: areaID)
        } catch {
            logger.error("createTerminalTab failed: \(error)")
        }
    }

    func selectTab(areaID: String, tabID: String) async {
        guard let service = workspaceService else { return }
        do {
            try await service.selectTab(areaID: areaID, tabID: tabID)
        } catch {
            logger.error("selectTab failed: \(error)")
        }
    }

    func closeTab(areaID: String, tabID: String) async {
        guard let service = workspaceService else { return }
        do {
            try await service.closeTab(areaID: areaID, tabID: tabID)
        } catch {
            logger.error("closeTab failed: \(error)")
        }
    }

    private func handleFailure(_ reason: ConnectionState.FailureReason) {
        let deviceID = activeDeviceID
        switch reason {
        case .needsRepair:
            lastConnectError = "Pairing was revoked on the desktop. Re-pair to reconnect."
            if let deviceID {
                Task { await self.setNeedsRepair(deviceID: deviceID, value: true) }
            }
        case .unreachable(let m):
            lastConnectError = "Could not reach the desktop: \(m)"
        case .other(let m):
            lastConnectError = m
        }
        activeDeviceID = nil
    }

    func clearConnectError() {
        guard lastConnectError != nil else { return }
        lastConnectError = nil
    }

    private func setNeedsRepair(deviceID: String, value: Bool) async {
        guard
            var record = try? await deviceRepository.loadAll().first(where: { $0.id == deviceID }),
            record.needsRepair != value
        else { return }
        record.needsRepair = value
        _ = try? await deviceRepository.upsert(record)
        devices = (try? await deviceRepository.loadAll()) ?? devices
    }

    private func applyDiscoveryUpdate(_ update: DiscoveryUpdate) async {
        discoveryState = update
        guard case .services(let services) = update else { return }
        await reconcileDevicesWithDiscovery(services)
    }

    private func reconcileDevicesWithDiscovery(_ services: [DiscoveredService]) async {
        let snapshot = devices
        var changed = false
        for service in services {
            guard let record = snapshot.first(where: { $0.serviceName == service.name }) else { continue }
            if record.host == service.host && record.port == service.port { continue }
            guard devices.contains(where: { $0.id == record.id }) else { continue }
            var updated = record
            updated.host = service.host
            updated.port = service.port
            _ = await upsertDevice(updated)
            changed = true
        }
        if changed {
            devices = (try? await deviceRepository.loadAll()) ?? devices
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

    func upsertDevice(_ record: DeviceRecord) async -> DeviceRecord? {
        do {
            let saved = try await deviceRepository.upsert(record)
            devices = (try? await deviceRepository.loadAll()) ?? devices
            return saved
        } catch {
            logger.error("upsertDevice failed: \(error)")
            return nil
        }
    }

    func removeDevice(id: String) async {
        if activeDeviceID == id {
            activeDeviceID = nil
            await connectionManager.disconnect()
        }
        try? await deviceRepository.remove(id: id)
        devices = (try? await deviceRepository.loadAll()) ?? devices
    }

    func pair(
        host: String,
        port: Int,
        label: String?,
        serviceName: String? = nil,
        phase: @MainActor @escaping (PairingPhase) -> Void = { _ in }
    ) async -> Result<DeviceRecord, PairingFailureReason> {
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
        let phaseStream = AsyncStream<PairingPhase>.makeStream()
        let phaseTask = Task { @MainActor in
            for await value in phaseStream.stream {
                phase(value)
            }
        }
        defer {
            phaseStream.continuation.finish()
            phaseTask.cancel()
        }
        let result = await pairingService.pair(
            endpoint: endpoint,
            identity: identity,
            phase: { phaseStream.continuation.yield($0) }
        )

        switch result {
        case .success(let pairingResult):
            let proposed = DeviceRecord(
                label: (label?.isEmpty == false ? label : nil) ?? serviceName ?? host,
                host: host,
                port: port,
                serviceName: serviceName,
                pairing: pairingResult.pairing
            )
            let saved = await upsertDevice(proposed) ?? proposed
            return .success(saved)
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
        let logger = self.logger
        Task { [settingsRepository, next] in
            do {
                try await settingsRepository.save(next)
            } catch {
                logger.error("settings save failed: \(error)")
            }
        }
    }

}
