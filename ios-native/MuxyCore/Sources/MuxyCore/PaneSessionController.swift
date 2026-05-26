import Foundation
import MuxyProtocol
import OSLog

public enum PaneSessionEvent: Sendable, Equatable {
    case snapshot([UInt8])
    case output([UInt8])
    case ownershipChanged(PaneOwnership)
    case attachFailed(String)
}

public actor PaneSessionController {
    private let client: MuxyWebSocketClient
    private let paneID: String
    private let logger: Logger
    private var continuation: AsyncStream<PaneSessionEvent>.Continuation?
    private var subscriptionTask: Task<Void, Never>?
    private var attached: Bool = false

    public init(client: MuxyWebSocketClient, paneID: String) {
        self.client = client
        self.paneID = paneID
        self.logger = Logger(subsystem: "com.muxy.app", category: "PaneSessionController")
    }

    public func stream() -> AsyncStream<PaneSessionEvent> {
        if continuation != nil {
            logger.error("stream() called more than once; returning an inert stream")
            return AsyncStream { $0.finish() }
        }
        return AsyncStream { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.detach() }
            }
        }
    }

    public func attach(cols: Int, rows: Int) async {
        if !attached {
            attached = true
            subscribeToEvents()
        }
        do {
            let params = AnyTypedValue(
                type: "takeOverPane",
                value: .object([
                    "paneID": .string(paneID),
                    "cols": .int(Int64(cols)),
                    "rows": .int(Int64(rows))
                ])
            )
            _ = try await client.send(method: .takeOverPane, params: params)
        } catch {
            logger.error("takeOverPane failed: \(error)")
            continuation?.yield(.attachFailed(String(describing: error)))
        }
    }

    public func sendInput(bytes: [UInt8]) async {
        guard attached, !bytes.isEmpty else { return }
        let base64 = Data(bytes).base64EncodedString()
        let params = AnyTypedValue(
            type: "terminalInput",
            value: .object([
                "paneID": .string(paneID),
                "bytes": .string(base64)
            ])
        )
        do {
            _ = try await client.send(method: .terminalInput, params: params)
        } catch {
            logger.error("terminalInput failed: \(error)")
        }
    }

    public func resize(cols: Int, rows: Int) async {
        guard attached else { return }
        let params = AnyTypedValue(
            type: "terminalResize",
            value: .object([
                "paneID": .string(paneID),
                "cols": .int(Int64(cols)),
                "rows": .int(Int64(rows))
            ])
        )
        do {
            _ = try await client.send(method: .terminalResize, params: params)
        } catch {
            logger.error("terminalResize failed: \(error)")
        }
    }

    public func detach() async {
        guard attached else {
            continuation?.finish()
            continuation = nil
            subscriptionTask?.cancel()
            subscriptionTask = nil
            return
        }
        attached = false
        subscriptionTask?.cancel()
        subscriptionTask = nil
        let params = AnyTypedValue(
            type: "releasePane",
            value: .object(["paneID": .string(paneID)])
        )
        _ = try? await client.send(method: .releasePane, params: params)
        continuation?.finish()
        continuation = nil
    }

    private func subscribeToEvents() {
        subscriptionTask = Task { [weak self, client, paneID] in
            let events: [String] = [
                EventName.terminalOutput.rawValue,
                EventName.terminalSnapshot.rawValue,
                EventName.paneOwnershipChanged.rawValue
            ]
            let params = AnyTypedValue(
                type: "subscribe",
                value: .object(["events": .array(events.map { .string($0) })])
            )
            _ = try? await client.send(method: .subscribe, params: params)
            let stream = await client.events()
            for await event in stream {
                if Task.isCancelled { return }
                await self?.handle(event: event, expectedPaneID: paneID)
            }
        }
    }

    private func handle(event: EventEnvelope, expectedPaneID: String) async {
        guard let data = event.payload.data else { return }
        switch event.payload.event {
        case EventName.terminalOutput.rawValue:
            guard let output: TerminalOutput = try? Self.decode(payload: data),
                  output.paneID == expectedPaneID,
                  let bytes = Data(base64Encoded: output.bytes) else { return }
            continuation?.yield(.output(Array(bytes)))
        case EventName.terminalSnapshot.rawValue:
            guard let snapshot: TerminalSnapshot = try? Self.decode(payload: data),
                  snapshot.paneID == expectedPaneID,
                  let bytes = Data(base64Encoded: snapshot.bytes) else { return }
            continuation?.yield(.snapshot(Array(bytes)))
        case EventName.paneOwnershipChanged.rawValue:
            guard let ownership: PaneOwnership = try? Self.decode(payload: data),
                  ownership.paneID == expectedPaneID else { return }
            continuation?.yield(.ownershipChanged(ownership))
        default:
            return
        }
    }

    private static func decode<T: Decodable>(payload: AnyTypedValue) throws -> T {
        guard let value = payload.value else {
            throw WebSocketClientError.protocolViolation("pane event payload missing value")
        }
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(AnyCodable(value))
        return try decoder.decode(T.self, from: data)
    }
}
