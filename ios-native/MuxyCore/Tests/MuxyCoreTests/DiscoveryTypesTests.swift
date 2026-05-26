import Foundation
import Testing
@testable import MuxyCore

@Suite("Discovery types")
struct DiscoveryTypesTests {
    @Test("DiscoveredService Equatable")
    func discoveredServiceEquatable() {
        let a = DiscoveredService(name: "Mac", host: "10.0.0.1", port: 4865)
        let b = DiscoveredService(name: "Mac", host: "10.0.0.1", port: 4865)
        let c = DiscoveredService(name: "Mac", host: "10.0.0.2", port: 4865)
        #expect(a == b)
        #expect(a != c)
    }

    @Test("DiscoveryUpdate Equatable")
    func discoveryUpdateEquatable() {
        let svc = DiscoveredService(name: "Mac", host: "h", port: 1)
        #expect(DiscoveryUpdate.searching == DiscoveryUpdate.searching)
        #expect(DiscoveryUpdate.services([svc]) == DiscoveryUpdate.services([svc]))
        #expect(DiscoveryUpdate.services([svc]) != DiscoveryUpdate.services([]))
        #expect(DiscoveryUpdate.permissionDenied != DiscoveryUpdate.searching)
        #expect(DiscoveryUpdate.failed("a") != DiscoveryUpdate.failed("b"))
    }
}
