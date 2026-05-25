import Foundation

public struct PairURIPayload: Sendable, Equatable {
    public let host: String
    public let port: Int
    public let serviceName: String?
    public let label: String?

    public init(host: String, port: Int, serviceName: String? = nil, label: String? = nil) {
        self.host = host
        self.port = port
        self.serviceName = serviceName
        self.label = label
    }
}

public enum PairURIParser {
    private static let scheme = "muxy:"
    private static let host = "//pair"

    public static func parse(_ input: String) -> PairURIPayload? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let prefix = "\(scheme)\(host)"
        guard trimmed.lowercased().hasPrefix(prefix) else { return nil }

        var rest = String(trimmed.dropFirst(prefix.count))
        if rest.hasPrefix("?") { rest.removeFirst() }
        guard !rest.isEmpty else { return nil }

        let items = queryItems(from: rest)
        guard let rawHost = items["host"]?.trimmingCharacters(in: .whitespaces),
              !rawHost.isEmpty else { return nil }
        guard let rawPort = items["port"]?.trimmingCharacters(in: .whitespaces),
              !rawPort.isEmpty else { return nil }

        guard let port = parseStrictInt(rawPort), (1...65_535).contains(port) else { return nil }

        let serviceName = items["service"]?.trimmingCharacters(in: .whitespaces).nonEmpty
        let label = items["label"]?.trimmingCharacters(in: .whitespaces).nonEmpty

        return PairURIPayload(host: rawHost, port: port, serviceName: serviceName, label: label)
    }

    private static func parseStrictInt(_ value: String) -> Int? {
        guard !value.isEmpty,
              value.allSatisfy({ $0.isASCII && ($0 == "-" || $0.isNumber) }) else { return nil }
        return Int(value)
    }

    private static func queryItems(from query: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in query.split(separator: "&", omittingEmptySubsequences: false) {
            guard let eqIdx = pair.firstIndex(of: "=") else {
                let key = decode(String(pair))
                if !key.isEmpty { result[key] = "" }
                continue
            }
            let key = decode(String(pair[..<eqIdx]))
            let value = decode(String(pair[pair.index(after: eqIdx)...]))
            if !key.isEmpty {
                result[key] = value
            }
        }
        return result
    }

    private static func decode(_ raw: String) -> String {
        let plusReplaced = raw.replacingOccurrences(of: "+", with: " ")
        return plusReplaced.removingPercentEncoding ?? plusReplaced
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
