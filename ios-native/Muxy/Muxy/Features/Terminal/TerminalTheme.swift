import MuxyProtocol
import SwiftTerm
import UIKit

@MainActor
struct MuxyTerminalTheme {
    let background: UIColor
    let foreground: UIColor
    let cursor: UIColor
    let palette: [SwiftTerm.Color]

    static let `default` = MuxyTerminalTheme(
        background: .black,
        foreground: .white,
        cursor: .white,
        palette: MuxyTerminalTheme.defaultPalette
    )

    static let defaultPalette: [SwiftTerm.Color] = [
        0x000000, 0xcc0000, 0x4e9a06, 0xc4a000,
        0x3465a4, 0x75507b, 0x06989a, 0xd3d7cf,
        0x555753, 0xef2929, 0x8ae234, 0xfce94f,
        0x729fcf, 0xad7fa8, 0x34e2e2, 0xeeeeec
    ].map(MuxyTerminalTheme.swiftTermColor(rgb:))

    static func from(pairing: Pairing?) -> MuxyTerminalTheme {
        guard let pairing else { return .default }
        return buildTheme(fg: pairing.themeFg, bg: pairing.themeBg, palette: pairing.themePalette)
    }

    static func from(change: ThemeChange, previous: MuxyTerminalTheme) -> MuxyTerminalTheme {
        let palette: [SwiftTerm.Color] = {
            guard let raw = change.palette, raw.count == 16 else { return previous.palette }
            return raw.map(MuxyTerminalTheme.swiftTermColor(rgb:))
        }()
        let fg = change.fg.map(uiColor(rgb:)) ?? previous.foreground
        let bg = change.bg.map(uiColor(rgb:)) ?? previous.background
        return MuxyTerminalTheme(background: bg, foreground: fg, cursor: fg, palette: palette)
    }

    private static func buildTheme(fg: Int?, bg: Int?, palette: [Int]?) -> MuxyTerminalTheme {
        let resolvedPalette: [SwiftTerm.Color] = {
            guard let raw = palette, raw.count == 16 else { return defaultPalette }
            return raw.map(swiftTermColor(rgb:))
        }()
        let resolvedFg = fg.map(uiColor(rgb:)) ?? .white
        let resolvedBg = bg.map(uiColor(rgb:)) ?? .black
        return MuxyTerminalTheme(background: resolvedBg, foreground: resolvedFg, cursor: resolvedFg, palette: resolvedPalette)
    }

    nonisolated private static func uiColor(rgb: Int) -> UIColor {
        let r = CGFloat((rgb >> 16) & 0xff) / 255.0
        let g = CGFloat((rgb >> 8) & 0xff) / 255.0
        let b = CGFloat(rgb & 0xff) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: 1)
    }

    nonisolated private static func swiftTermColor(rgb: Int) -> SwiftTerm.Color {
        let r = UInt16((rgb >> 16) & 0xff) << 8 | UInt16((rgb >> 16) & 0xff)
        let g = UInt16((rgb >> 8) & 0xff) << 8 | UInt16((rgb >> 8) & 0xff)
        let b = UInt16(rgb & 0xff) << 8 | UInt16(rgb & 0xff)
        return SwiftTerm.Color(red: r, green: g, blue: b)
    }
}
