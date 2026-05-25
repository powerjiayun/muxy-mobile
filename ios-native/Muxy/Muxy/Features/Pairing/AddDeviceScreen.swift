import MuxyCore
import SwiftUI

struct AddDeviceScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = defaultPort
    @State private var saving: Bool = false
    @State private var error: String?

    private static let defaultPort = "4865"

    private var canSubmit: Bool {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let trimmedPort = port.trimmingCharacters(in: .whitespaces)
        return !trimmedHost.isEmpty && Int(trimmedPort) != nil && !saving
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                nearbyCard
                fieldsCard
                if let error {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal, Theme.Spacing.xs)
                }
                ctaButton
                hintFooter
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .navigationTitle("Add device")
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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.present(.scanPair)
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                }
                .accessibilityLabel("Scan pairing QR code")
            }
        }
    }

    private var nearbyCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("Nearby Muxy desktops")
            VStack {
                HStack(spacing: Theme.Spacing.sm) {
                    ProgressView()
                    Text("Bonjour discovery arrives in Phase 4")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    private var fieldsCard: some View {
        VStack(spacing: 0) {
            fieldRow(label: "Name", placeholder: "Work desktop", text: $name, capitalize: .words, keyboard: .default)
            divider
            fieldRow(label: "Host", placeholder: "192.168.1.10 or your-host.local", text: $host, capitalize: .never, keyboard: .URL, disableAutocorrect: true)
            divider
            fieldRow(label: "Port", placeholder: AddDeviceScreen.defaultPort, text: $port, capitalize: .never, keyboard: .numberPad, disableAutocorrect: true)
        }
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func fieldRow(
        label: String,
        placeholder: String,
        text: Binding<String>,
        capitalize: TextInputAutocapitalization,
        keyboard: UIKeyboardType,
        disableAutocorrect: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label.uppercased())
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            TextField(placeholder, text: text)
                .font(.body)
                .textInputAutocapitalization(capitalize)
                .keyboardType(keyboard)
                .autocorrectionDisabled(disableAutocorrect)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm + 2)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(height: 0.5)
    }

    private var ctaButton: some View {
        Button(action: { Task { await save() } }) {
            HStack(spacing: Theme.Spacing.sm) {
                if saving { ProgressView() }
                Text("Pair")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canSubmit)
        .padding(.top, Theme.Spacing.xs)
    }

    private var hintFooter: some View {
        Text("On your desktop, open Muxy › Settings › Mobile and toggle the server on.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .tracking(0.5)
            .padding(.horizontal, Theme.Spacing.xs)
    }

    private func save() async {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard let portNumber = Int(port.trimmingCharacters(in: .whitespaces)),
              (1...65_535).contains(portNumber) else {
            error = "Port must be between 1 and 65535."
            return
        }
        error = nil
        saving = true
        defer { saving = false }

        let record = DeviceRecord(
            label: trimmedName.isEmpty ? trimmedHost : trimmedName,
            host: trimmedHost,
            port: portNumber
        )
        await environment.upsertDevice(record)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AddDeviceScreen()
    }
    .environment(AppEnvironment())
    .environment(AppRouter())
}
