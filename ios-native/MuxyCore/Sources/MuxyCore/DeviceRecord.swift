import Foundation
import MuxyProtocol

public struct DeviceRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var label: String
    public var host: String
    public var port: Int
    public var serviceName: String?
    public var createdAt: Date
    public var lastUsedAt: Date?
    public var needsRepair: Bool
    public var pairing: Pairing?

    public init(
        id: String = UUID().uuidString,
        label: String,
        host: String,
        port: Int,
        serviceName: String? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        needsRepair: Bool = false,
        pairing: Pairing? = nil
    ) {
        self.id = id
        self.label = label
        self.host = host
        self.port = port
        self.serviceName = serviceName
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.needsRepair = needsRepair
        self.pairing = pairing
    }
}
