import Foundation

public struct SettingsRecord: Codable, Equatable, Sendable {
    public var hasOnboarded: Bool
    public var useNerdFont: Bool
    public var autoFocusTerminal: Bool
    public var demoMode: Bool

    public init(hasOnboarded: Bool, useNerdFont: Bool, autoFocusTerminal: Bool, demoMode: Bool) {
        self.hasOnboarded = hasOnboarded
        self.useNerdFont = useNerdFont
        self.autoFocusTerminal = autoFocusTerminal
        self.demoMode = demoMode
    }

    public static let `default` = SettingsRecord(
        hasOnboarded: false,
        useNerdFont: false,
        autoFocusTerminal: true,
        demoMode: false
    )
}
