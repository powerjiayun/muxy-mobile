import Foundation
import MuxyProtocol

public enum WebSocketClientError: Error, Equatable {
    case socketClosed
    case requestTimeout
    case protocolViolation(String)
    case server(code: Int, message: String)
}

public actor MuxyWebSocketClient {
    public let url: URL

    private let urlSession: URLSession
    private var task: URLSessionWebSocketTask?
    private var nextRequestID: Int = 0
    private var pending: [String: PendingRequest] = [:]
    private var eventContinuation: AsyncStream<EventEnvelope>.Continuation?
    private var receiveLoopTask: Task<Void, Never>?
    private var didFinish = false

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(url: URL, urlSession: URLSession = .shared) {
        self.url = url
        self.urlSession = urlSession
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func connect() async throws {
        guard task == nil else { return }
        let task = urlSession.webSocketTask(with: url)
        self.task = task
        task.resume()
        startReceiveLoop()
    }

    public func close() async {
        finishAll(error: WebSocketClientError.socketClosed)
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        receiveLoopTask?.cancel()
        receiveLoopTask = nil
    }

    public func events() -> AsyncStream<EventEnvelope> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
            continuation.onTermination = { _ in }
        }
    }

    public func send(
        method: MuxyProtocol.Method,
        params: AnyTypedValue?,
        timeout: TimeInterval = 30
    ) async throws -> AnyTypedValue? {
        guard task != nil else { throw WebSocketClientError.socketClosed }

        let id = allocateID()
        let envelope = RequestEnvelope(
            payload: RequestPayload(id: id, method: method.rawValue, params: params)
        )
        let data = try encoder.encode(envelope)
        guard let json = String(data: data, encoding: .utf8) else {
            throw WebSocketClientError.protocolViolation("encoding failed")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.failRequest(id: id, with: WebSocketClientError.requestTimeout)
            }
            pending[id] = PendingRequest(continuation: continuation, timeoutTask: timeoutTask)

            Task { [weak self] in
                do {
                    try await self?.task?.send(.string(json))
                } catch {
                    await self?.failRequest(id: id, with: error)
                }
            }
        }
    }

    private func allocateID() -> String {
        nextRequestID += 1
        return String(nextRequestID)
    }

    private func startReceiveLoop() {
        receiveLoopTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    private func receiveLoop() async {
        while let task, !didFinish {
            do {
                let message = try await task.receive()
                handle(message: message)
            } catch {
                finishAll(error: WebSocketClientError.socketClosed)
                return
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .data(let value):
            data = value
        case .string(let value):
            data = Data(value.utf8)
        @unknown default:
            return
        }
        do {
            let envelope = try IncomingEnvelopeDecoder.decode(data)
            switch envelope {
            case .response(let response):
                completeRequest(response: response.payload)
            case .event(let event):
                eventContinuation?.yield(event)
            }
        } catch {
            return
        }
    }

    private func completeRequest(response: ResponsePayload) {
        guard let pending = pending.removeValue(forKey: response.id) else { return }
        pending.timeoutTask?.cancel()
        if let error = response.error {
            pending.continuation.resume(
                throwing: WebSocketClientError.server(code: error.code, message: error.message)
            )
            return
        }
        pending.continuation.resume(returning: response.result)
    }

    private func failRequest(id: String, with error: Error) {
        guard let pending = pending.removeValue(forKey: id) else { return }
        pending.timeoutTask?.cancel()
        pending.continuation.resume(throwing: error)
    }

    private func finishAll(error: Error) {
        guard !didFinish else { return }
        didFinish = true
        for (_, pending) in pending {
            pending.timeoutTask?.cancel()
            pending.continuation.resume(throwing: error)
        }
        pending.removeAll()
        eventContinuation?.finish()
        eventContinuation = nil
    }
}

private struct PendingRequest {
    let continuation: CheckedContinuation<AnyTypedValue?, Error>
    let timeoutTask: Task<Void, Never>?
}
