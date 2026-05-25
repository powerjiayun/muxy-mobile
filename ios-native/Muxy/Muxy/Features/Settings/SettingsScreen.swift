import SwiftUI

struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var bindableEnvironment = environment

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                section(label: "Terminal") {
                    VStack(spacing: Theme.Spacing.md) {
                        toggleRow(
                            title: "Use Nerd Font",
                            hint: "JetBrains Mono with powerline and icon glyphs.",
                            isOn: $bindableEnvironment.useNerdFont
                        )
                        toggleRow(
                            title: "Auto-focus terminal",
                            hint: "Focus the terminal automatically when switching or creating tabs. May open the on-screen keyboard.",
                            isOn: $bindableEnvironment.autoFocusTerminal
                        )
                    }
                }
                section(label: "Demo") {
                    toggleRow(
                        title: "Demo Mode",
                        hint: "Loads sample data so you can try the app without a desktop. Switching it off restores your real devices.",
                        isOn: $bindableEnvironment.demoMode
                    )
                }
                section(label: "About") {
                    HStack {
                        Text("Version")
                            .font(.body)
                        Spacer()
                        Text(appVersion)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Close")
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .padding(.horizontal, Theme.Spacing.xs)
            content()
                .padding(Theme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                )
        }
    }

    private func toggleRow(title: String, hint: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(hint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
    }

    private var appVersion: String {
        let dict = Bundle.main.infoDictionary
        let version = dict?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = dict?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        SettingsScreen()
    }
    .environment(AppEnvironment())
    .environment(AppRouter())
}
