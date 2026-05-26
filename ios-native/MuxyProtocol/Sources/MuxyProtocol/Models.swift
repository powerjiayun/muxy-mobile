import Foundation

public struct Project: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let path: String
    public let sortOrder: Int
    public let createdAt: String
    public let icon: String?
    public let logo: String?
    public let iconColor: String?

    public init(
        id: String,
        name: String,
        path: String,
        sortOrder: Int,
        createdAt: String,
        icon: String? = nil,
        logo: String? = nil,
        iconColor: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.icon = icon
        self.logo = logo
        self.iconColor = iconColor
    }
}

public struct Worktree: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let path: String
    public let branch: String
    public let isPrimary: Bool
    public let canBeRemoved: Bool
    public let createdAt: String
}

public enum TabKind: String, Codable, Sendable, Equatable {
    case terminal
    case vcs
    case editor
    case diffViewer
}

public struct Tab: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: TabKind
    public let title: String
    public let isPinned: Bool
    public let paneID: String?

    public init(id: String, kind: TabKind, title: String, isPinned: Bool, paneID: String?) {
        self.id = id
        self.kind = kind
        self.title = title
        self.isPinned = isPinned
        self.paneID = paneID
    }
}

public struct TabArea: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let projectPath: String
    public let tabs: [Tab]
    public let activeTabID: String?
}

public enum SplitDirection: String, Codable, Sendable, Equatable {
    case horizontal
    case vertical
}

public enum SplitPosition: String, Codable, Sendable, Equatable {
    case first
    case second
}

public indirect enum SplitNode: Codable, Sendable, Equatable {
    case split(Split)
    case tabArea(TabArea)

    private enum CodingKeys: String, CodingKey {
        case type
        case split
        case tabArea
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "split":
            let split = try container.decode(Split.self, forKey: .split)
            self = .split(split)
        case "tabArea":
            let area = try container.decode(TabArea.self, forKey: .tabArea)
            self = .tabArea(area)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container, debugDescription: "Unknown SplitNode type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .split(let split):
            try container.encode("split", forKey: .type)
            try container.encode(split, forKey: .split)
        case .tabArea(let area):
            try container.encode("tabArea", forKey: .type)
            try container.encode(area, forKey: .tabArea)
        }
    }
}

public struct Split: Codable, Sendable, Equatable {
    public let direction: SplitDirection
    public let first: SplitNode
    public let second: SplitNode
}

public struct Workspace: Codable, Sendable, Equatable {
    public let projectID: String
    public let worktreeID: String
    public let focusedAreaID: String
    public let root: SplitNode
}

public struct TerminalCell: Codable, Sendable, Equatable {
    public let codepoint: Int
    public let fg: Int
    public let bg: Int
    public let flags: Int
}

public struct TerminalCells: Codable, Sendable, Equatable {
    public let paneID: String
    public let cols: Int
    public let rows: Int
    public let cursorX: Int
    public let cursorY: Int
    public let cursorVisible: Bool
    public let defaultFg: Int
    public let defaultBg: Int
    public let cells: [TerminalCell]
}

public struct TerminalOutput: Codable, Sendable, Equatable {
    public let paneID: String
    public let bytes: String
}

public struct TerminalSnapshot: Codable, Sendable, Equatable {
    public let paneID: String
    public let bytes: String
}

public enum PaneOwner: Codable, Sendable, Equatable {
    case mac(deviceName: String)
    case remote(deviceID: String, deviceName: String)

    private enum CodingKeys: String, CodingKey {
        case mac
        case remote
    }

    private struct MacOwner: Codable, Equatable {
        let deviceName: String
    }

    private struct RemoteOwner: Codable, Equatable {
        let deviceID: String
        let deviceName: String
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let mac = try container.decodeIfPresent(MacOwner.self, forKey: .mac) {
            self = .mac(deviceName: mac.deviceName)
            return
        }
        if let remote = try container.decodeIfPresent(RemoteOwner.self, forKey: .remote) {
            self = .remote(deviceID: remote.deviceID, deviceName: remote.deviceName)
            return
        }
        throw DecodingError.dataCorrupted(
            .init(codingPath: container.codingPath, debugDescription: "Unknown PaneOwner shape")
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .mac(let deviceName):
            try container.encode(MacOwner(deviceName: deviceName), forKey: .mac)
        case .remote(let deviceID, let deviceName):
            try container.encode(RemoteOwner(deviceID: deviceID, deviceName: deviceName), forKey: .remote)
        }
    }
}

public struct PaneOwnership: Codable, Sendable, Equatable {
    public let paneID: String
    public let owner: PaneOwner
}

public struct DeviceTheme: Codable, Sendable, Equatable {
    public let themeFg: Int?
    public let themeBg: Int?
    public let themePalette: [Int]?
}

public struct ThemeChange: Codable, Sendable, Equatable {
    public let fg: Int?
    public let bg: Int?
    public let palette: [Int]?
}

public struct Pairing: Codable, Sendable, Equatable {
    public let clientID: String
    public let deviceName: String
    public let themeFg: Int?
    public let themeBg: Int?
    public let themePalette: [Int]?
}

public enum GitFileStatus: String, Codable, Sendable, Equatable {
    case added
    case modified
    case deleted
    case renamed
    case copied
    case untracked
    case unmerged
}

public struct GitFile: Codable, Sendable, Equatable {
    public let path: String
    public let status: GitFileStatus
    public let isUntracked: Bool
}

public enum VCSPRChecksStatus: String, Codable, Sendable, Equatable {
    case none
    case pending
    case success
    case failure
}

public struct VCSPRChecks: Codable, Sendable, Equatable {
    public let status: VCSPRChecksStatus
    public let passing: Int
    public let failing: Int
    public let pending: Int
    public let total: Int
}

public enum VCSPRMergeStateStatus: String, Codable, Sendable, Equatable {
    case clean = "CLEAN"
    case hasHooks = "HAS_HOOKS"
    case unstable = "UNSTABLE"
    case behind = "BEHIND"
    case blocked = "BLOCKED"
    case dirty = "DIRTY"
    case draft = "DRAFT"
    case unknown = "UNKNOWN"
}

public struct VCSPullRequest: Codable, Sendable, Equatable {
    public let url: String
    public let number: Int
    public let state: String
    public let isDraft: Bool
    public let baseBranch: String
    public let mergeable: Bool?
    public let mergeStateStatus: VCSPRMergeStateStatus?
    public let checks: VCSPRChecks?
}

public enum VCSMergeMethod: String, Codable, Sendable, Equatable {
    case merge
    case squash
    case rebase
}

public struct VCSStatus: Codable, Sendable, Equatable {
    public let branch: String
    public let aheadCount: Int
    public let behindCount: Int
    public let hasUpstream: Bool
    public let stagedFiles: [GitFile]
    public let changedFiles: [GitFile]
    public let defaultBranch: String?
    public let pullRequest: VCSPullRequest?
}

public struct VCSBranches: Codable, Sendable, Equatable {
    public let current: String
    public let locals: [String]
    public let defaultBranch: String?
}

public struct VCSPRCreated: Codable, Sendable, Equatable {
    public let url: String
    public let number: Int
}

public enum VCSDiffRowKind: String, Codable, Sendable, Equatable {
    case hunk
    case context
    case addition
    case deletion
    case collapsed
}

public struct VCSDiffRow: Codable, Sendable, Equatable {
    public let kind: VCSDiffRowKind
    public let oldLineNumber: Int?
    public let newLineNumber: Int?
    public let text: String
}

public struct VCSDiff: Codable, Sendable, Equatable {
    public let filePath: String
    public let rows: [VCSDiffRow]
    public let additions: Int
    public let deletions: Int
    public let truncated: Bool
    public let isBinary: Bool
}

public struct AuthParams: Codable, Sendable, Equatable {
    public let deviceID: String
    public let deviceName: String
    public let token: String

    public init(deviceID: String, deviceName: String, token: String) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.token = token
    }
}

public struct RegisterParams: Codable, Sendable, Equatable {
    public let deviceName: String

    public init(deviceName: String) {
        self.deviceName = deviceName
    }
}
