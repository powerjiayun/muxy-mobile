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

    var body: some View {
        MuxyTerminalView(
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
                newHandle.becomeFirstResponder()
            }
        )
        .background(Color.black)
        .task(id: paneID) {
            await startSession()
        }
        .onDisappear {
            stopSession()
        }
    }

    private func startSession() async {
        stopSession()
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
        case .ownershipChanged, .attachFailed:
            break
        }
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
