import Testing
@testable import MuxyProtocol

@Suite("PairURIParser")
struct PairURITests {
    @Test("parses a minimal valid URI")
    func parsesMinimal() {
        let result = PairURIParser.parse("muxy://pair?host=example.local&port=4865")
        #expect(result == PairURIPayload(host: "example.local", port: 4865))
    }

    @Test("parses URI with service and label")
    func parsesWithServiceAndLabel() {
        let uri = "muxy://pair?host=10.0.0.5&port=4865&service=Saeeds-Mac&label=Saeed%27s%20Mac"
        let result = PairURIParser.parse(uri)
        #expect(result == PairURIPayload(host: "10.0.0.5", port: 4865, serviceName: "Saeeds-Mac", label: "Saeed's Mac"))
    }

    @Test("accepts uppercase scheme")
    func acceptsUppercaseScheme() {
        #expect(PairURIParser.parse("MUXY://pair?host=h&port=1") != nil)
    }

    @Test("trims surrounding whitespace")
    func trimsWhitespace() {
        let result = PairURIParser.parse("  muxy://pair?host=h&port=1  ")
        #expect(result == PairURIPayload(host: "h", port: 1))
    }

    @Test("rejects empty input")
    func rejectsEmpty() {
        #expect(PairURIParser.parse("") == nil)
    }

    @Test("rejects wrong scheme")
    func rejectsWrongScheme() {
        #expect(PairURIParser.parse("https://pair?host=h&port=1") == nil)
    }

    @Test("rejects missing host")
    func rejectsMissingHost() {
        #expect(PairURIParser.parse("muxy://pair?port=4865") == nil)
    }

    @Test("rejects missing port")
    func rejectsMissingPort() {
        #expect(PairURIParser.parse("muxy://pair?host=h") == nil)
    }

    @Test("rejects empty query")
    func rejectsEmptyQuery() {
        #expect(PairURIParser.parse("muxy://pair") == nil)
    }

    @Test("rejects non-integer port")
    func rejectsNonIntegerPort() {
        #expect(PairURIParser.parse("muxy://pair?host=h&port=abc") == nil)
        #expect(PairURIParser.parse("muxy://pair?host=h&port=12.5") == nil)
    }

    @Test("rejects port out of range")
    func rejectsPortOutOfRange() {
        #expect(PairURIParser.parse("muxy://pair?host=h&port=0") == nil)
        #expect(PairURIParser.parse("muxy://pair?host=h&port=65536") == nil)
        #expect(PairURIParser.parse("muxy://pair?host=h&port=-1") == nil)
    }

    @Test("drops empty optional params")
    func dropsEmptyOptionals() {
        let result = PairURIParser.parse("muxy://pair?host=h&port=1&service=&label=")
        #expect(result?.serviceName == nil)
        #expect(result?.label == nil)
    }
}
