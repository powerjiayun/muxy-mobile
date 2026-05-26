import Foundation
import Network
import OSLog

public struct DiscoveredService: Sendable, Equatable, Identifiable {
    public let name: String
    public let host: String
    public let port: Int

    public var id: String { name }

    public init(name: String, host: String, port: Int) {
        self.name = name
        self.host = host
        self.port = port
    }
}

public enum DiscoveryUpdate: Sendable, Equatable {
    case searching
    case services([DiscoveredService])
    case permissionDenied
    case failed(String)
}

public actor DiscoveryService {
    public static let defaultServiceType = "_muxy._tcp"
    public static let defaultDomain = "local."

    private let serviceType: String
    private let domain: String
    private let queue: DispatchQueue
    private let logger: Logger

    private var browser: NWBrowser?
    private var updateContinuation: AsyncStream<DiscoveryUpdate>.Continuation?
    private var connections: [String: NWConnection] = [:]
    private var resolved: [String: DiscoveredService] = [:]
    private var pending: Set<String> = []
    private var isShuttingDown = false

    public init(
        serviceType: String = DiscoveryService.defaultServiceType,
        domain: String = DiscoveryService.defaultDomain
    ) {
        self.serviceType = serviceType
        self.domain = domain
        self.queue = DispatchQueue(label: "com.muxy.app.discovery")
        self.logger = Logger(subsystem: "com.muxy.app", category: "DiscoveryService")
    }

    public func stream() -> AsyncStream<DiscoveryUpdate> {
        if updateContinuation != nil {
            logger.error("stream() called more than once; returning an inert stream")
            return AsyncStream { $0.finish() }
        }
        return AsyncStream { continuation in
            self.updateContinuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.shutdown() }
            }
            start()
        }
    }

    public func stop() {
        shutdown()
    }

    private func start() {
        let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: domain)
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: descriptor, using: parameters)

        browser.stateUpdateHandler = { [weak self] state in
            Task { await self?.handleBrowserState(state) }
        }
        browser.browseResultsChangedHandler = { [weak self] results, changes in
            Task { await self?.handleResults(results, changes: changes) }
        }
        self.browser = browser
        updateContinuation?.yield(.searching)
        browser.start(queue: queue)
    }

    private func handleBrowserState(_ state: NWBrowser.State) {
        switch state {
        case .failed(let error):
            if case let .dns(code) = error, code == kDNSServiceErr_PolicyDenied {
                updateContinuation?.yield(.permissionDenied)
            } else {
                updateContinuation?.yield(.failed(error.localizedDescription))
            }
        case .waiting(let error):
            updateContinuation?.yield(.failed(error.localizedDescription))
        case .cancelled, .setup, .ready:
            break
        @unknown default:
            break
        }
    }

    private func handleResults(_ results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            if case .changed(_, let new, _) = change,
               case let .service(name, _, _, _) = new.endpoint {
                discardResolved(name: name)
            }
        }

        var seenNames: Set<String> = []
        for result in results {
            guard case let .service(name, _, _, _) = result.endpoint else { continue }
            seenNames.insert(name)
            if resolved[name] != nil || pending.contains(name) { continue }
            pending.insert(name)
            resolve(name: name, endpoint: result.endpoint)
        }

        var changed = false
        for name in Array(resolved.keys) where !seenNames.contains(name) {
            resolved.removeValue(forKey: name)
            changed = true
        }
        for name in Array(pending) where !seenNames.contains(name) {
            pending.remove(name)
            connections[name]?.cancel()
            connections.removeValue(forKey: name)
        }

        if changed {
            emitSnapshot()
        }
    }

    private func discardResolved(name: String) {
        if resolved.removeValue(forKey: name) != nil {
            emitSnapshot()
        }
        if let connection = connections.removeValue(forKey: name) {
            connection.cancel()
        }
        pending.remove(name)
    }

    private func resolve(name: String, endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        connections[name] = connection
        connection.stateUpdateHandler = { [weak self] state in
            Task { await self?.handleConnection(name: name, state: state) }
        }
        connection.start(queue: queue)
    }

    private func handleConnection(name: String, state: NWConnection.State) {
        guard let connection = connections[name] else { return }
        switch state {
        case .ready:
            if let endpoint = connection.currentPath?.remoteEndpoint,
               let (host, port) = Self.hostPort(from: endpoint) {
                resolved[name] = DiscoveredService(name: name, host: host, port: port)
                pending.remove(name)
                emitSnapshot()
            } else {
                logger.error("Resolved endpoint for \(name) did not expose a hostPort; dropping")
                pending.remove(name)
            }
            connection.cancel()
            connections.removeValue(forKey: name)
        case .waiting(let error):
            logger.error("Resolve for \(name) entered waiting: \(error.localizedDescription)")
            pending.remove(name)
            connection.cancel()
            connections.removeValue(forKey: name)
        case .failed, .cancelled:
            pending.remove(name)
            connections.removeValue(forKey: name)
        default:
            break
        }
    }

    private static func hostPort(from endpoint: NWEndpoint) -> (String, Int)? {
        switch endpoint {
        case let .hostPort(host, port):
            let hostString: String
            switch host {
            case .name(let name, _):
                hostString = name
            case .ipv4(let v4):
                hostString = stripZone("\(v4)")
            case .ipv6(let v6):
                hostString = bracketedIPv6("\(v6)")
            @unknown default:
                return nil
            }
            return (hostString, Int(port.rawValue))
        default:
            return nil
        }
    }

    private static func stripZone(_ address: String) -> String {
        if let idx = address.firstIndex(of: "%") {
            return String(address[..<idx])
        }
        return address
    }

    private static func bracketedIPv6(_ address: String) -> String {
        let encoded = address.replacingOccurrences(of: "%", with: "%25")
        return "[\(encoded)]"
    }

    private func emitSnapshot() {
        let snapshot = resolved.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        updateContinuation?.yield(.services(snapshot))
    }

    private func shutdown() {
        guard !isShuttingDown else { return }
        isShuttingDown = true
        browser?.cancel()
        browser = nil
        for (_, connection) in connections {
            connection.cancel()
        }
        connections.removeAll()
        resolved.removeAll()
        pending.removeAll()
        let continuation = updateContinuation
        updateContinuation = nil
        continuation?.finish()
        isShuttingDown = false
    }
}
