import Foundation
import Testing
@testable import MuxyProtocol

@Suite("Envelope round-trip")
struct EnvelopeTests {
    @Test("encodes a request envelope with typed params")
    func encodesRequestEnvelope() throws {
        let envelope = RequestEnvelope(
            payload: RequestPayload(
                id: "req-1",
                method: Method.terminalInput.rawValue,
                params: AnyTypedValue(
                    type: "terminalInput",
                    value: .object([
                        "paneID": .string("pane-1"),
                        "bytes": .string("aGVsbG8=")
                    ])
                )
            )
        )

        let data = try JSONEncoder.sorted.encode(envelope)
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains("\"type\":\"request\""))
        #expect(json.contains("\"method\":\"terminalInput\""))
        #expect(json.contains("\"id\":\"req-1\""))
        #expect(json.contains("\"paneID\":\"pane-1\""))
    }

    @Test("decodes a response envelope into the response case")
    func decodesResponseEnvelope() throws {
        let json = """
        {
          "type": "response",
          "payload": {
            "id": "req-1",
            "result": { "type": "ok" }
          }
        }
        """.data(using: .utf8)!

        let incoming = try IncomingEnvelopeDecoder.decode(json)
        guard case .response(let response) = incoming else {
            Issue.record("Expected response envelope")
            return
        }
        #expect(response.payload.id == "req-1")
        #expect(response.payload.result?.type == "ok")
        #expect(response.payload.error == nil)
    }

    @Test("decodes a response envelope error")
    func decodesResponseError() throws {
        let json = """
        {
          "type": "response",
          "payload": {
            "id": "req-7",
            "error": { "code": 42, "message": "boom" }
          }
        }
        """.data(using: .utf8)!

        let incoming = try IncomingEnvelopeDecoder.decode(json)
        guard case .response(let response) = incoming else {
            Issue.record("Expected response envelope")
            return
        }
        #expect(response.payload.error?.code == 42)
        #expect(response.payload.error?.message == "boom")
    }

    @Test("decodes an event envelope")
    func decodesEventEnvelope() throws {
        let json = """
        {
          "type": "event",
          "payload": {
            "event": "terminalOutput",
            "data": {
              "type": "terminalOutput",
              "value": { "paneID": "p1", "bytes": "QUJD" }
            }
          }
        }
        """.data(using: .utf8)!

        let incoming = try IncomingEnvelopeDecoder.decode(json)
        guard case .event(let event) = incoming else {
            Issue.record("Expected event envelope")
            return
        }
        #expect(event.payload.event == EventName.terminalOutput.rawValue)
        #expect(event.payload.data?.type == "terminalOutput")
    }

    @Test("rejects unknown envelope type")
    func rejectsUnknownEnvelope() {
        let json = """
        { "type": "nope", "payload": {} }
        """.data(using: .utf8)!

        #expect(throws: (any Error).self) {
            _ = try IncomingEnvelopeDecoder.decode(json)
        }
    }
}

extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
