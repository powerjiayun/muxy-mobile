import SwiftUI
import UIKit

enum TerminalModifier: String, CaseIterable, Identifiable {
    case ctrl, shift, alt, cmd
    var id: String { rawValue }

    var glyph: String {
        switch self {
        case .ctrl: "⌃"
        case .shift: "⇧"
        case .alt: "⌥"
        case .cmd: "⌘"
        }
    }

    func apply(to bytes: [UInt8]) -> [UInt8] {
        guard let first = bytes.first else { return bytes }
        switch self {
        case .ctrl:
            if let mapped = ctrlMap(first) { return [mapped] }
            return bytes
        case .alt, .cmd:
            return [0x1b] + bytes
        case .shift:
            return bytes
        }
    }

    private func ctrlMap(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 0x40...0x5f: return byte - 0x40
        case 0x60...0x7e: return byte - 0x60
        case 0x20: return 0x00
        case 0x3f: return 0x7f
        default: return nil
        }
    }
}

struct TerminalAccessoryBar: View {
    let onBytes: ([UInt8]) -> Void

    @State private var armed: TerminalModifier?
    @State private var activeModifier: TerminalModifier = .ctrl

    var body: some View {
        HStack(spacing: 10) {
            keyPill
            DPadControl { bytes in send(bytes) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var keyPill: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                key("esc", bytes: [0x1b])
                modifierKey
                key("tab", bytes: [0x09])
                iconButton("doc.on.clipboard", label: "Paste") { paste() }
                key("~", bytes: [0x7e])
                key("|", bytes: [0x7c])
                key("/", bytes: [0x2f])
                key("-", bytes: [0x2d])
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(height: 44)
        .background(.thinMaterial, in: Capsule())
    }

    private func key(_ title: String, bytes: [UInt8]) -> some View {
        Button { send(bytes) } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(minWidth: 32)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func iconButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var modifierKey: some View {
        let isArmed = armed == activeModifier
        return Menu {
            ForEach(TerminalModifier.allCases) { modifier in
                Button {
                    activeModifier = modifier
                    armed = modifier
                } label: {
                    Label(modifier.rawValue, systemImage: modifier == activeModifier ? "checkmark" : "")
                }
            }
        } label: {
            Text(activeModifier.rawValue)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(isArmed ? Color.white : .primary)
                .frame(minWidth: 40)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(isArmed ? Theme.Palette.accent : Color.clear, in: Capsule())
        } primaryAction: {
            armed = isArmed ? nil : activeModifier
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    private func send(_ bytes: [UInt8]) {
        let payload = armed.map { $0.apply(to: bytes) } ?? bytes
        armed = nil
        onBytes(payload)
    }

    private func paste() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
        onBytes(Array(text.utf8))
    }
}

struct DPadControl: View {
    let onBytes: ([UInt8]) -> Void

    private let outerSize: CGFloat = 44
    private let thumbSize: CGFloat = 18
    private let deadZone: CGFloat = 5

    @State private var thumbOffset: CGSize = .zero
    @State private var activeDirection: Direction?
    @State private var repeatTask: Task<Void, Never>?

    private enum Direction {
        case up, down, left, right

        var bytes: [UInt8] {
            switch self {
            case .up: [0x1b, 0x5b, 0x41]
            case .down: [0x1b, 0x5b, 0x42]
            case .right: [0x1b, 0x5b, 0x43]
            case .left: [0x1b, 0x5b, 0x44]
            }
        }

        var unit: CGSize {
            switch self {
            case .up: .init(width: 0, height: -1)
            case .down: .init(width: 0, height: 1)
            case .left: .init(width: -1, height: 0)
            case .right: .init(width: 1, height: 0)
            }
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.35))
            Circle()
                .fill(Color.primary.opacity(0.55))
                .frame(width: thumbSize, height: thumbSize)
                .offset(thumbOffset)
                .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.8), value: thumbOffset)
        }
        .frame(width: outerSize, height: outerSize)
        .background(.thinMaterial, in: Circle())
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in handleDrag(translation: value.translation) }
                .onEnded { _ in
                    thumbOffset = .zero
                    activeDirection = nil
                    stopRepeating()
                }
        )
    }

    private func handleDrag(translation: CGSize) {
        let dx = translation.width
        let dy = translation.height
        let magnitude = hypot(dx, dy)
        guard magnitude > deadZone else {
            if activeDirection != nil {
                stopRepeating()
                activeDirection = nil
            }
            thumbOffset = .zero
            return
        }
        let direction: Direction = abs(dx) > abs(dy)
            ? (dx > 0 ? .right : .left)
            : (dy > 0 ? .down : .up)

        let maxReach = (outerSize - thumbSize) / 2 - 2
        thumbOffset = CGSize(
            width: direction.unit.width * maxReach,
            height: direction.unit.height * maxReach
        )

        guard direction != activeDirection else { return }
        activeDirection = direction
        startRepeating(direction)
    }

    private func startRepeating(_ direction: Direction) {
        stopRepeating()
        onBytes(direction.bytes)
        repeatTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            while !Task.isCancelled {
                onBytes(direction.bytes)
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
    }

    private func stopRepeating() {
        repeatTask?.cancel()
        repeatTask = nil
    }
}
