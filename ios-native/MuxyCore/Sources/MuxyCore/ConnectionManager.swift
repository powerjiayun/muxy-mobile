import Foundation
import MuxyProtocol

public enum ConnectionState: Sendable, Equatable {
    case idle
    case connecting
    case authenticating
    case connected
    case reconnecting(attempt: Int)
    case failed(reason: FailureReason)
    case suspended

    public enum FailureReason: Sendable, Equatable {
        case needsRepair
        case unreachable(String)
        case other(String)
    }
}

public actor ConnectionManager {
    private let policy: ReconnectPolicy
    private let identityProvider: @Sendable () async throws -> PairingService.Identity
    private let clientFactory: @Sendable (URL) -> MuxyWebSocketClient

    private var activeRecord: DeviceRecord?
    private var activeClient: MuxyWebSocketClient?
    private var stateContinuation: AsyncStream<ConnectionState>.Continuation?
    private var lifecycleTask: Task<Void, Never>?
    private(set) public var state: ConnectionState = .idle

    public init(
        policy: ReconnectPolicy = ReconnectPolicy(),
        clientFactory: @escaping @Sendable (URL) -> MuxyWebSocketClient = { MuxyWebSocketClient(url: $0) },
        identityProvider: @escaping @Sendable () async throws -> PairingService.Identity
    ) {
        self.policy = policy
        self.clientFactory = clientFactory
        self.identityProvider = identityProvider
    }

    public func stateStream() -> AsyncStream<ConnectionState> {
        precondition(stateContinuation == nil, "ConnectionManager.stateStream may only be subscribed once")
        return AsyncStream { continuation in
            self.stateContinuation = continuation
            continuation.yield(self.state)
        }
    }

    public func activeClientHandle() -> MuxyWebSocketClient? { activeClient }

    public func connect(to record: DeviceRecord) async {
        cancelLifecycle()
        await tearDownClient()
        activeRecord = record
        startLifecycle()
    }

    public func disconnect() async {
        cancelLifecycle()
        await tearDownClient()
        activeRecord = nil
        transition(to: .idle)
    }

    public func suspend() async {
        cancelLifecycle()
        await tearDownClient()
        if activeRecord != nil {
            transition(to: .suspended)
        }
    }

    public func resume() async {
        guard activeRecord != nil, case .suspended = state else { return }
        startLifecycle()
    }

    private func startLifecycle() {
        cancelLifecycle()
        lifecycleTask = Task { [weak self] in
            await self?.runLifecycle()
        }
    }

    private func cancelLifecycle() {
        lifecycleTask?.cancel()
        lifecycleTask = nil
    }

    private func runLifecycle() async {
        var attempt = 0
        while !Task.isCancelled, let record = activeRecord {
            if attempt == 0 {
                transition(to: .connecting)
            } else {
                transition(to: .reconnecting(attempt: attempt))
                let delay = policy.delay(attempt: attempt - 1)
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    return
                }
                if Task.isCancelled { return }
            }

            let outcome = await attemptConnection(record: record)
            switch outcome {
            case .connected:
                attempt = 0
                await waitForDrop()
                if Task.isCancelled || activeRecord == nil { return }
                await tearDownClient()
                attempt = 1
            case .needsRepair:
                transition(to: .failed(reason: .needsRepair))
                return
            case .invalid(let reason):
                transition(to: .failed(reason: reason))
                return
            case .retry:
                attempt += 1
            }
        }
    }

    private enum AttemptOutcome {
        case connected
        case needsRepair
        case invalid(ConnectionState.FailureReason)
        case retry
    }

    private func attemptConnection(record: DeviceRecord) async -> AttemptOutcome {
        guard let url = URL(string: "ws://\(record.host):\(record.port)") else {
            return .invalid(.other("invalid host or port"))
        }
        let identity: PairingService.Identity
        do {
            identity = try await identityProvider()
        } catch {
            return .invalid(.other("identity unavailable: \(error)"))
        }

        let client = clientFactory(url)
        do {
            try await client.connect()
        } catch {
            await client.close()
            transition(to: .failed(reason: .unreachable(error.localizedDescription)))
            return .retry
        }

        transition(to: .authenticating)
        let authParams = AnyTypedValue(
            type: "authenticateDevice",
            value: .object([
                "deviceID": .string(identity.deviceID),
                "deviceName": .string(identity.deviceName),
                "token": .string(identity.token)
            ])
        )

        do {
            _ = try await client.send(method: .authenticateDevice, params: authParams)
            activeClient = client
            transition(to: .connected)
            return .connected
        } catch let WebSocketClientError.server(code, _) where code == 401 {
            await client.close()
            return .needsRepair
        } catch {
            await client.close()
            transition(to: .failed(reason: .other(String(describing: error))))
            return .retry
        }
    }

    private func waitForDrop() async {
        guard let client = activeClient else { return }
        do {
            let stream = try await client.events()
            for await _ in stream {
                if Task.isCancelled { return }
            }
        } catch {
            return
        }
    }

    private func tearDownClient() async {
        await activeClient?.close()
        activeClient = nil
    }

    private func transition(to newState: ConnectionState) {
        state = newState
        stateContinuation?.yield(newState)
    }
}
