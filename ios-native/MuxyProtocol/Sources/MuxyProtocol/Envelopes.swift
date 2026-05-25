import Foundation

public struct AnyCodable: Codable, Sendable, Equatable {
    public let value: AnyCodableValue

    public init(_ value: AnyCodableValue) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try AnyCodableValue(from: container)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try value.encode(to: &container)
    }
}

public indirect enum AnyCodableValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([AnyCodableValue])
    case object([String: AnyCodableValue])

    init(from container: SingleValueDecodingContainer) throws {
        if container.decodeNil() {
            self = .null
            return
        }
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode(Int64.self) { self = .int(v); return }
        if let v = try? container.decode(Double.self) { self = .double(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        if let v = try? container.decode([AnyCodableValue].self) { self = .array(v); return }
        if let v = try? container.decode([String: AnyCodableValue].self) { self = .object(v); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }

    func encode(to container: inout SingleValueEncodingContainer) throws {
        switch self {
        case .null: try container.encodeNil()
        case .bool(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }
}

extension AnyCodableValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(from: container)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try encode(to: &container)
    }
}

public struct TypedValue<Value: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public let type: String
    public let value: Value

    public init(type: String, value: Value) {
        self.type = type
        self.value = value
    }
}

public struct TypedValueOptional<Value: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public let type: String
    public let value: Value?

    public init(type: String, value: Value? = nil) {
        self.type = type
        self.value = value
    }
}

public struct AnyTypedValue: Codable, Sendable, Equatable {
    public let type: String
    public let value: AnyCodableValue?

    public init(type: String, value: AnyCodableValue? = nil) {
        self.type = type
        self.value = value
    }
}

public struct RequestPayload: Codable, Sendable, Equatable {
    public let id: String
    public let method: String
    public let params: AnyTypedValue?

    public init(id: String, method: String, params: AnyTypedValue?) {
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct RequestEnvelope: Codable, Sendable, Equatable {
    public let type: String
    public let payload: RequestPayload

    public init(payload: RequestPayload) {
        self.type = "request"
        self.payload = payload
    }
}

public struct WSErrorPayload: Codable, Sendable, Equatable, Error {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
}

public struct ResponsePayload: Codable, Sendable, Equatable {
    public let id: String
    public let result: AnyTypedValue?
    public let error: WSErrorPayload?

    public init(id: String, result: AnyTypedValue? = nil, error: WSErrorPayload? = nil) {
        self.id = id
        self.result = result
        self.error = error
    }
}

public struct ResponseEnvelope: Codable, Sendable, Equatable {
    public let type: String
    public let payload: ResponsePayload
}

public struct EventPayload: Codable, Sendable, Equatable {
    public let event: String
    public let data: AnyTypedValue?

    public init(event: String, data: AnyTypedValue? = nil) {
        self.event = event
        self.data = data
    }
}

public struct EventEnvelope: Codable, Sendable, Equatable {
    public let type: String
    public let payload: EventPayload
}

public enum IncomingEnvelope: Sendable, Equatable {
    case response(ResponseEnvelope)
    case event(EventEnvelope)
}

public enum IncomingEnvelopeDecoder {
    public static func decode(_ data: Data) throws -> IncomingEnvelope {
        let decoder = JSONDecoder()
        let probe = try decoder.decode(EnvelopeProbe.self, from: data)
        switch probe.type {
        case "response":
            return .response(try decoder.decode(ResponseEnvelope.self, from: data))
        case "event":
            return .event(try decoder.decode(EventEnvelope.self, from: data))
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Unknown envelope type: \(probe.type)")
            )
        }
    }

    private struct EnvelopeProbe: Decodable {
        let type: String
    }
}
