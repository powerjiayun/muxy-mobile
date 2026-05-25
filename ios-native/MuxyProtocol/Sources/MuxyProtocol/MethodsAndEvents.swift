import Foundation

public enum Method: String, Sendable, CaseIterable {
    case authenticateDevice
    case pairDevice
    case registerDevice
    case listProjects
    case selectProject
    case listWorktrees
    case selectWorktree
    case getWorkspace
    case createTab
    case closeTab
    case selectTab
    case splitArea
    case closeArea
    case focusArea
    case takeOverPane
    case releasePane
    case terminalInput
    case terminalResize
    case terminalScroll
    case getTerminalContent
    case getProjectLogo
    case subscribe
    case unsubscribe
    case getVCSStatus
    case vcsRefresh
    case vcsCommit
    case vcsPush
    case vcsPull
    case vcsStageFiles
    case vcsUnstageFiles
    case vcsDiscardFiles
    case vcsListBranches
    case vcsSwitchBranch
    case vcsCreateBranch
    case vcsCreatePR
    case vcsMergePullRequest
    case vcsAddWorktree
    case vcsRemoveWorktree
    case vcsGetDiff
}

public enum EventName: String, Sendable, CaseIterable {
    case workspaceChanged
    case terminalOutput
    case terminalSnapshot
    case notificationReceived
    case projectsChanged
    case paneOwnershipChanged
    case themeChanged
}

public enum ResultType {
    public static let ok = "ok"
    public static let pairing = "pairing"
    public static let deviceInfo = "deviceInfo"
    public static let projects = "projects"
    public static let worktrees = "worktrees"
    public static let workspace = "workspace"
    public static let tab = "tab"
    public static let terminalCells = "terminalCells"
    public static let projectLogo = "projectLogo"
    public static let vcsStatus = "vcsStatus"
    public static let vcsBranches = "vcsBranches"
    public static let vcsPRCreated = "vcsPRCreated"
    public static let vcsDiff = "vcsDiff"
}
