import Foundation
import MuxyProtocol

public enum PairingPhase: Sendable, Equatable {
    case connecting
    case authenticating
    case awaitingApproval
    case authenticated(Pairing)
    case failed(reason: PairingFailureReason)
}

public enum PairingFailureReason: Sendable, Equatable, Error {
    case denied
    case timedOut
    case unreachable(String)
    case protocolViolation(String)
    case other(message: String)
}

public struct PairingResult: Sendable, Equatable {
    public let pairing: Pairing
    public let token: String
}

public actor PairingService {
    public struct Endpoint: Sendable, Equatable {
        public let host: String
        public let port: Int

        public init(host: String, port: Int) {
            self.host = host
            self.port = port
        }

        public var url: URL? {
            URL(string: "ws://\(host):\(port)")
        }
    }

    public struct Identity: Sendable, Equatable {
        public let deviceID: String
        public let deviceName: String
        public let token: String

        public init(deviceID: String, deviceName: String, token: String) {
            self.deviceID = deviceID
            self.deviceName = deviceName
            self.token = token
        }
    }

    private let clientFactory: @Sendable (URL) -> MuxyWebSocketClient
    private let pairTimeout: TimeInterval
    private let authTimeout: TimeInterval

    public init(
        clientFactory: @escaping @Sendable (URL) -> MuxyWebSocketClient = { MuxyWebSocketClient(url: $0) },
        pairTimeout: TimeInterval = 120,
        authTimeout: TimeInterval = 15
    ) {
        self.clientFactory = clientFactory
        self.pairTimeout = pairTimeout
        self.authTimeout = authTimeout
    }

    public func pair(
        endpoint: Endpoint,
        identity: Identity,
        phase: @Sendable @escaping (PairingPhase) -> Void
    ) async -> Result<PairingResult, PairingFailureReason> {
        guard let url = endpoint.url else {
            let reason = PairingFailureReason.protocolViolation("invalid host/port")
            phase(.failed(reason: reason))
            return .failure(reason)
        }

        phase(.connecting)
        let client = clientFactory(url)
        do {
            try await client.connect()
        } catch {
            let reason = PairingFailureReason.unreachable(error.localizedDescription)
            phase(.failed(reason: reason))
            await client.close()
            return .failure(reason)
        }

        phase(.authenticating)
        let authParams = AnyTypedValue(
            type: "authenticateDevice",
            value: .object([
                "deviceID": .string(identity.deviceID),
                "deviceName": .string(identity.deviceName),
                "token": .string(identity.token)
            ])
        )

        let authResult = await sendPairing(
            client: client,
            method: .authenticateDevice,
            params: authParams,
            timeout: authTimeout
        )

        switch authResult {
        case .success(let pairing):
            phase(.authenticated(pairing))
            await client.close()
            return .success(PairingResult(pairing: pairing, token: identity.token))

        case .needsPairing:
            phase(.awaitingApproval)
            let pairParams = AnyTypedValue(
                type: "pairDevice",
                value: .object([
                    "deviceID": .string(identity.deviceID),
                    "deviceName": .string(identity.deviceName),
                    "token": .string(identity.token)
                ])
            )
            let pairResult = await sendPairing(
                client: client,
                method: .pairDevice,
                params: pairParams,
                timeout: pairTimeout
            )
            await client.close()
            switch pairResult {
            case .success(let pairing):
                phase(.authenticated(pairing))
                return .success(PairingResult(pairing: pairing, token: identity.token))
            case .needsPairing:
                let reason = PairingFailureReason.protocolViolation("server requested re-pairing during pairDevice")
                phase(.failed(reason: reason))
                return .failure(reason)
            case .failed(let reason):
                phase(.failed(reason: reason))
                return .failure(reason)
            }

        case .failed(let reason):
            await client.close()
            phase(.failed(reason: reason))
            return .failure(reason)
        }
    }

    private enum PairingAttempt {
        case success(Pairing)
        case needsPairing
        case failed(PairingFailureReason)
    }

    private func sendPairing(
        client: MuxyWebSocketClient,
        method: MuxyProtocol.Method,
        params: AnyTypedValue,
        timeout: TimeInterval
    ) async -> PairingAttempt {
        do {
            let result = try await client.send(method: method, params: params, timeout: timeout)
            guard let result, result.type == ResultType.pairing else {
                return .failed(.protocolViolation("missing pairing payload"))
            }
            do {
                let pairing = try decodePairing(from: result)
                return .success(pairing)
            } catch {
                return .failed(.protocolViolation("decode pairing: \(error)"))
            }
        } catch let WebSocketClientError.server(code, message) {
            switch code {
            case 401:
                return .needsPairing
            case 403:
                return .failed(.denied)
            case 408:
                return .failed(.timedOut)
            default:
                return .failed(.other(message: "[\(code)] \(message)"))
            }
        } catch WebSocketClientError.requestTimeout {
            return .failed(.timedOut)
        } catch {
            return .failed(.unreachable(error.localizedDescription))
        }
    }

    private func decodePairing(from result: AnyTypedValue) throws -> Pairing {
        guard case .object(let dict) = result.value else {
            throw WebSocketClientError.protocolViolation("pairing value not object")
        }
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(AnyCodableValue.object(dict))
        return try decoder.decode(Pairing.self, from: data)
    }
}
