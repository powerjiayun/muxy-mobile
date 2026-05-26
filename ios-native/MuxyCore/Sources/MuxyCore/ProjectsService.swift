import Foundation
import MuxyProtocol
import OSLog

public enum ProjectsUpdate: Sendable, Equatable {
    case loading
    case projects([Project])
    case failed(String)
}

public actor ProjectsService {
    private let client: MuxyWebSocketClient
    private let logger: Logger
    private var continuation: AsyncStream<ProjectsUpdate>.Continuation?
    private var subscriptionTask: Task<Void, Never>?

    public init(client: MuxyWebSocketClient) {
        self.client = client
        self.logger = Logger(subsystem: "com.muxy.app", category: "ProjectsService")
    }

    public func stream() -> AsyncStream<ProjectsUpdate> {
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

    public func loadLogo(projectID: String) async -> Data? {
        let params = AnyTypedValue(
            type: "getProjectLogo",
            value: .object(["projectID": .string(projectID)])
        )
        do {
            let result = try await client.send(method: .getProjectLogo, params: params)
            guard let result, case .object(let dict) = result.value,
                  case .string(let base64) = dict["pngData"] else { return nil }
            return Data(base64Encoded: base64)
        } catch {
            logger.error("getProjectLogo \(projectID) failed: \(error)")
            return nil
        }
    }

    public func stop() async {
        subscriptionTask?.cancel()
        subscriptionTask = nil
        continuation?.finish()
        continuation = nil
    }

    private func bootstrap() async {
        await load()
        subscribeToProjectsChanged()
    }

    private func load() async {
        continuation?.yield(.loading)
        do {
            let result = try await client.send(method: .listProjects, params: nil)
            let projects = try decodeProjects(from: result)
            continuation?.yield(.projects(projects))
        } catch {
            continuation?.yield(.failed(String(describing: error)))
        }
    }

    private func subscribeToProjectsChanged() {
        subscriptionTask = Task { [weak self, client] in
            let params = AnyTypedValue(
                type: "subscribe",
                value: .object(["events": .array([.string(EventName.projectsChanged.rawValue)])])
            )
            _ = try? await client.send(method: .subscribe, params: params)
            let events = await client.events()
            for await event in events {
                if Task.isCancelled { return }
                guard event.payload.event == EventName.projectsChanged.rawValue,
                      let data = event.payload.data else { continue }
                await self?.handleProjectsChanged(payload: data)
            }
        }
    }

    private func handleProjectsChanged(payload: AnyTypedValue) async {
        do {
            let projects = try decodeProjects(from: payload)
            continuation?.yield(.projects(projects))
        } catch {
            logger.error("projectsChanged decode failed: \(error)")
        }
    }

    private func decodeProjects(from result: AnyTypedValue?) throws -> [Project] {
        guard let result, case .array(let arr) = result.value else {
            throw WebSocketClientError.protocolViolation("projects payload not array")
        }
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(AnyCodableValue.array(arr))
        return try decoder.decode([Project].self, from: data)
    }
}
