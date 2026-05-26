import MuxyCore
import SwiftUI

struct AddDeviceScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    let prefill: AddDevicePrefill?

    @State private var name: String
    @State private var host: String
    @State private var port: String
    @State private var serviceName: String?
    @State private var phase: PairingPhase?
    @State private var error: String?

    init(prefill: AddDevicePrefill? = nil) {
        self.prefill = prefill
        if let prefill {
            _name = State(initialValue: prefill.label)
            _host = State(initialValue: prefill.host)
            _port = State(initialValue: String(prefill.port))
            _serviceName = State(initialValue: prefill.serviceName)
        } else {
            _name = State(initialValue: "")
            _host = State(initialValue: "")
            _port = State(initialValue: AddDeviceScreen.defaultPort)
            _serviceName = State(initialValue: nil)
        }
    }

    private static let defaultPort = "4865"

    private var isBusy: Bool { phase != nil }

    private var canSubmit: Bool {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let trimmedPort = port.trimmingCharacters(in: .whitespaces)
        return !trimmedHost.isEmpty && Int(trimmedPort) != nil && !isBusy
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                nearbyCard
                fieldsCard
                if let phaseHint {
                    HStack(spacing: Theme.Spacing.sm) {
                        ProgressView()
                        Text(phaseHint)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, Theme.Spacing.xs)
                }
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
        .navigationTitle(prefill == nil ? "Add device" : "Re-pair device")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Close")
                .disabled(isBusy)
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

    private var phaseHint: String? {
        guard let phase else { return nil }
        switch phase {
        case .connecting, .authenticating: return "Connecting to Muxy…"
        case .awaitingApproval: return "Open Muxy on your desktop and approve this device."
        case .authenticated: return "Paired"
        case .failed: return nil
        }
    }

    private var nearbyCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("Nearby Muxy desktops")
            VStack(spacing: 0) {
                nearbyContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private var nearbyContent: some View {
        switch environment.discoveryState {
        case .searching:
            nearbyMessage(spinner: true, text: "Searching the local network…")
        case .services(let services) where services.isEmpty:
            nearbyMessage(spinner: false, text: "No Muxy desktops found yet.")
        case .services(let services):
            ForEach(Array(services.enumerated()), id: \.element.id) { index, service in
                if index > 0 { divider }
                Button {
                    select(service)
                } label: {
                    nearbyRow(service: service, selected: service.name == serviceName)
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
            }
        case .permissionDenied:
            nearbyMessage(spinner: false, text: "Local network access is off. Enable it in Settings → Muxy → Local Network.")
        case .failed(let message):
            nearbyMessage(spinner: false, text: "Discovery failed: \(message)")
        }
    }

    private func nearbyMessage(spinner: Bool, text: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            if spinner { ProgressView() }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nearbyRow(service: DiscoveredService, selected: Bool) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text("\(service.host):\(service.port)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.accent)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .contentShape(Rectangle())
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
        .onChange(of: host) { _, _ in invalidateServiceNameIfMismatched() }
        .onChange(of: port) { _, _ in invalidateServiceNameIfMismatched() }
    }

    private func invalidateServiceNameIfMismatched() {
        guard let captured = serviceName,
              case .services(let services) = environment.discoveryState,
              let match = services.first(where: { $0.name == captured }) else { return }
        if host != match.host || port != String(match.port) {
            serviceName = nil
        }
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
                .disabled(isBusy)
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
        Button(action: { Task { await pair() } }) {
            Text(isBusy ? "Pairing…" : "Pair")
                .font(.body.weight(.semibold))
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

    private func select(_ service: DiscoveredService) {
        host = service.host
        port = String(service.port)
        serviceName = service.name
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            name = service.name
        }
    }

    private func pair() async {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard let portNumber = Int(port.trimmingCharacters(in: .whitespaces)),
              (1...65_535).contains(portNumber) else {
            error = "Port must be between 1 and 65535."
            return
        }
        error = nil
        phase = .connecting

        let result = await environment.pair(
            host: trimmedHost,
            port: portNumber,
            label: trimmedName,
            serviceName: serviceName,
            phase: { phase = $0 }
        )
        switch result {
        case .success:
            dismiss()
        case .failure(let reason):
            phase = nil
            error = describe(reason)
        }
    }

    private func describe(_ reason: PairingFailureReason) -> String {
        switch reason {
        case .denied: return "Pairing was denied on the desktop."
        case .timedOut: return "Pairing timed out. Try again and approve faster."
        case .unreachable(let m): return "Could not reach Muxy: \(m)"
        case .protocolViolation(let m): return "Protocol error: \(m)"
        case .other(let m): return m
        }
    }
}

#Preview {
    NavigationStack {
        AddDeviceScreen()
    }
    .environment(AppEnvironment())
    .environment(AppRouter())
}
