import MuxyCore
import MuxyProtocol
import SwiftUI

struct TerminalTabView: View {
    let paneID: String

    @Environment(AppEnvironment.self) private var environment
    @State private var handle: MuxyTerminalHandle?
    @State private var controller: PaneSessionController?
    @State private var streamTask: Task<Void, Never>?
    @State private var lastSize: (cols: Int, rows: Int)?
    @State private var ownership: PaneOwnership?
    @State private var attachError: String?
    @State private var isRetrying: Bool = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                MuxyTerminalView(
                    theme: environment.terminalTheme,
                    useNerdFont: environment.settings.useNerdFont,
                    onInput: { data in
                        let bytes = Array(data)
                        Task { await controller?.sendInput(bytes: bytes) }
                    },
                    onSize: { cols, rows in
                        if let last = lastSize, last.cols == cols, last.rows == rows { return }
                        lastSize = (cols, rows)
                        Task { await controller?.resize(cols: cols, rows: rows) }
                    },
                    configure: { newHandle in
                        handle = newHandle
                        if environment.settings.autoFocusTerminal {
                            newHandle.becomeFirstResponder()
                        }
                    }
                )
                TerminalAccessoryBar { bytes in
                    handle?.becomeFirstResponder()
                    Task { await controller?.sendInput(bytes: bytes) }
                }
            }
            .background(Color(environment.terminalTheme.background))

            if let overlayMessage {
                overlayView(overlayMessage)
            }
        }
        .task(id: paneID) {
            await startSession()
        }
        .onDisappear {
            stopSession()
        }
    }

    private var overlayMessage: OverlayMessage? {
        if let attachError {
            return OverlayMessage(title: "Couldn't attach to pane", body: attachError, action: "Try again")
        }
        if let ownership, !isOwnedBySelf(ownership.owner) {
            return OverlayMessage(
                title: "Pane controlled elsewhere",
                body: "\(ownerName(ownership.owner)) is currently controlling this pane.",
                action: "Take back"
            )
        }
        return nil
    }

    private func overlayView(_ message: OverlayMessage) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "rectangle.dashed.badge.person")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(message.title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(message.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(message.action) {
                Task { await retryAttach() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRetrying)
        }
        .padding(Theme.Spacing.xl)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color.black.opacity(0.4))
    }

    private struct OverlayMessage {
        let title: String
        let body: String
        let action: String
    }

    private func isOwnedBySelf(_ owner: PaneOwner) -> Bool {
        switch owner {
        case .mac:
            return false
        case .remote(let deviceID, _):
            return deviceID == environment.localDeviceID
        }
    }

    private func ownerName(_ owner: PaneOwner) -> String {
        switch owner {
        case .mac(let name): return name
        case .remote(_, let name): return name
        }
    }

    private func startSession() async {
        stopSession()
        ownership = nil
        attachError = nil
        guard let client = await environment.connectionManager.activeClientHandle() else { return }
        let session = PaneSessionController(client: client, paneID: paneID)
        controller = session
        let stream = await session.stream()
        let initialCols = lastSize?.cols ?? 80
        let initialRows = lastSize?.rows ?? 24
        await session.attach(cols: initialCols, rows: initialRows)
        streamTask = Task { @MainActor in
            for await event in stream {
                handle(event: event)
            }
        }
    }

    private func handle(event: PaneSessionEvent) {
        switch event {
        case .snapshot(let bytes), .output(let bytes):
            handle?.feed(bytes: bytes)
            attachError = nil
        case .ownershipChanged(let value):
            ownership = value
        case .attachFailed(let message):
            attachError = message
        }
    }

    private func retryAttach() async {
        guard !isRetrying else { return }
        isRetrying = true
        defer { isRetrying = false }
        let cols = lastSize?.cols ?? 80
        let rows = lastSize?.rows ?? 24
        await controller?.attach(cols: cols, rows: rows)
    }

    private func stopSession() {
        streamTask?.cancel()
        streamTask = nil
        let existing = controller
        controller = nil
        if let existing {
            Task { await existing.detach() }
        }
    }
}
