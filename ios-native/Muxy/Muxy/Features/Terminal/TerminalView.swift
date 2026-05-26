import SwiftTerm
import SwiftUI
import UIKit

struct MuxyTerminalView: UIViewRepresentable {
    let onInput: (ArraySlice<UInt8>) -> Void
    let onSize: (Int, Int) -> Void
    let configure: (MuxyTerminalHandle) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onInput: onInput, onSize: onSize)
    }

    func makeUIView(context: Context) -> SwiftTerm.TerminalView {
        let view = SwiftTerm.TerminalView(frame: .zero)
        view.terminalDelegate = context.coordinator
        view.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        view.backgroundColor = .black
        view.nativeBackgroundColor = .black
        view.nativeForegroundColor = .white
        configure(MuxyTerminalHandle(view: view))
        return view
    }

    func updateUIView(_ uiView: SwiftTerm.TerminalView, context: Context) {
        context.coordinator.onInput = onInput
        context.coordinator.onSize = onSize
    }

    final class Coordinator: NSObject, TerminalViewDelegate {
        var onInput: (ArraySlice<UInt8>) -> Void
        var onSize: (Int, Int) -> Void

        init(onInput: @escaping (ArraySlice<UInt8>) -> Void, onSize: @escaping (Int, Int) -> Void) {
            self.onInput = onInput
            self.onSize = onSize
        }

        func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
            onInput(data)
        }

        func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
            onSize(newCols, newRows)
        }

        func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}
        func scrolled(source: SwiftTerm.TerminalView, position: Double) {}
        func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String: String]) {}
        func bell(source: SwiftTerm.TerminalView) {}
        func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {}
        func iTermContent(source: SwiftTerm.TerminalView, content: ArraySlice<UInt8>) {}
        func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}
    }
}

@MainActor
final class MuxyTerminalHandle {
    private weak var view: SwiftTerm.TerminalView?

    init(view: SwiftTerm.TerminalView) {
        self.view = view
    }

    func feed(bytes: [UInt8]) {
        view?.feed(byteArray: bytes[...])
    }

    func currentSize() -> (cols: Int, rows: Int)? {
        guard let terminal = view?.getTerminal() else { return nil }
        return (terminal.cols, terminal.rows)
    }

    func becomeFirstResponder() {
        _ = view?.becomeFirstResponder()
    }
}
