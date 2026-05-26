import Foundation
import MuxyProtocol
import OSLog

public enum WorkspaceUpdate: Sendable, Equatable {
    case loading
    case workspace(Workspace)
    case failed(String)
}

public actor WorkspaceService {
    private let client: MuxyWebSocketClient
    private let projectID: String
    private let logger: Logger
    private var continuation: AsyncStream<WorkspaceUpdate>.Continuation?
    private var subscriptionTask: Task<Void, Never>?

    public init(client: MuxyWebSocketClient, projectID: String) {
        self.client = client
        self.projectID = projectID
        self.logger = Logger(subsystem: "com.muxy.app", category: "WorkspaceService")
    }

    public func stream() -> AsyncStream<WorkspaceUpdate> {
        if continuation != nil {
            logger.error("stream() called more than once; returning an inert stream")
            return AsyncStream { $0.finish() }
        }
        return AsyncStream { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.stop() }
            }
            Task { await self.bootstrap() }
        }
    }

    public func refresh() async {
        await load()
    }

    public func createTerminalTab(areaID: String?) async throws {
        var value: [String: AnyCodableValue] = [
            "projectID": .string(projectID),
            "kind": .string(TabKind.terminal.rawValue)
        ]
        if let areaID {
            value["areaID"] = .string(areaID)
        }
        let params = AnyTypedValue(type: "createTab", value: .object(value))
        _ = try await client.send(method: .createTab, params: params)
        await load()
    }

    public func selectTab(areaID: String, tabID: String) async throws {
        let params = AnyTypedValue(
            type: "selectTab",
            value: .object([
                "projectID": .string(projectID),
                "areaID": .string(areaID),
                "tabID": .string(tabID)
            ])
        )
        _ = try await client.send(method: .selectTab, params: params)
    }

    public func closeTab(areaID: String, tabID: String) async throws {
        let params = AnyTypedValue(
            type: "closeTab",
            value: .object([
                "projectID": .string(projectID),
                "areaID": .string(areaID),
                "tabID": .string(tabID)
            ])
        )
        _ = try await client.send(method: .closeTab, params: params)
    }

    public func stop() async {
        subscriptionTask?.cancel()
        subscriptionTask = nil
        continuation?.finish()
        continuation = nil
    }

    private func bootstrap() async {
        await load()
        subscribeToWorkspaceChanged()
    }

    private func load() async {
        continuation?.yield(.loading)
        do {
            let params = AnyTypedValue(
                type: "getWorkspace",
                value: .object(["projectID": .string(projectID)])
            )
            let result = try await client.send(method: .getWorkspace, params: params)
            let workspace = try decodeWorkspace(from: result)
            continuation?.yield(.workspace(workspace))
        } catch {
            continuation?.yield(.failed(String(describing: error)))
        }
    }

    private func subscribeToWorkspaceChanged() {
        subscriptionTask = Task { [weak self, client, projectID] in
            let params = AnyTypedValue(
                type: "subscribe",
                value: .object(["events": .array([.string(EventName.workspaceChanged.rawValue)])])
            )
            _ = try? await client.send(method: .subscribe, params: params)
            let events = await client.events()
            for await event in events {
                if Task.isCancelled { return }
                guard event.payload.event == EventName.workspaceChanged.rawValue,
                      let data = event.payload.data else { continue }
                await self?.handleWorkspaceChanged(payload: data, expectedProjectID: projectID)
            }
        }
    }

    private func handleWorkspaceChanged(payload: AnyTypedValue, expectedProjectID: String) async {
        do {
            let workspace = try decodeWorkspace(from: payload)
            guard workspace.projectID == expectedProjectID else { return }
            continuation?.yield(.workspace(workspace))
        } catch {
            logger.error("workspaceChanged decode failed: \(error)")
        }
    }

    private func decodeWorkspace(from result: AnyTypedValue?) throws -> Workspace {
        guard let value = result?.value else {
            throw WebSocketClientError.protocolViolation("workspace payload missing")
        }
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(AnyCodable(value))
        return try decoder.decode(Workspace.self, from: data)
    }
}
