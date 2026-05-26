import MuxyCore
import SwiftUI

struct ConnectionBanner: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        if let appearance = appearance(for: environment.connectionState) {
            HStack(spacing: Theme.Spacing.sm) {
                if appearance.showsSpinner {
                    ProgressView()
                        .controlSize(.small)
                        .tint(appearance.foreground)
                }
                Text(appearance.text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(appearance.foreground)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(appearance.background)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func appearance(for state: ConnectionState) -> Appearance? {
        switch state {
        case .idle, .connected:
            return nil
        case .connecting:
            return Appearance(text: "Connecting…", background: .gray.opacity(0.18), foreground: .primary, showsSpinner: true)
        case .authenticating:
            return Appearance(text: "Authenticating…", background: .gray.opacity(0.18), foreground: .primary, showsSpinner: true)
        case .reconnecting(let attempt):
            let label = attempt <= 1 ? "Reconnecting…" : "Reconnecting (attempt \(attempt))…"
            return Appearance(text: label, background: .orange.opacity(0.18), foreground: .primary, showsSpinner: true)
        case .failed(let reason):
            return Appearance(text: describe(reason), background: .red.opacity(0.18), foreground: .red, showsSpinner: false)
        case .suspended:
            return Appearance(text: "Paused (app backgrounded)", background: .gray.opacity(0.18), foreground: .primary, showsSpinner: false)
        }
    }

    private func describe(_ reason: ConnectionState.FailureReason) -> String {
        switch reason {
        case .needsRepair: return "Pairing rejected — re-pair the device."
        case .unreachable(let m): return "Unreachable: \(m)"
        case .other(let m): return m
        }
    }

    private struct Appearance {
        let text: String
        let background: Color
        let foreground: Color
        let showsSpinner: Bool
    }
}
