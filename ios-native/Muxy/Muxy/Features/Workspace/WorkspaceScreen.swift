import MuxyCore
import MuxyProtocol
import SwiftUI

struct WorkspaceScreen: View {
    let deviceID: String
    let projectID: String

    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    var body: some View {
        Group {
            switch environment.workspaceState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .workspace(let workspace):
                workspaceContent(workspace)
            case .failed(let message):
                failureView(message)
            }
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .navigationTitle(projectTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await environment.createTerminalTab(areaID: focusedAreaID)
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!canCreateTab)
            }
        }
        .task(id: projectID) {
            environment.startWorkspace(projectID: projectID)
        }
        .onDisappear {
            environment.stopWorkspace()
        }
        .onChange(of: environment.connectionState) { _, newState in
            switch newState {
            case .idle:
                router.popToRoot()
            case .failed(.needsRepair):
                router.popToRoot()
            default:
                break
            }
        }
    }

    private var projectTitle: String {
        if case .workspace(let workspace) = environment.workspaceState,
           let area = workspace.focusedArea {
            return area.projectPath.split(separator: "/").last.map(String.init) ?? "Workspace"
        }
        return "Workspace"
    }

    private var focusedAreaID: String? {
        if case .workspace(let workspace) = environment.workspaceState {
            return workspace.focusedAreaID
        }
        return nil
    }

    private var canCreateTab: Bool {
        if case .workspace = environment.workspaceState { return true }
        return false
    }

    private func workspaceContent(_ workspace: Workspace) -> some View {
        let area = workspace.focusedArea
        return VStack(spacing: 0) {
            if let area {
                TabStrip(
                    area: area,
                    onSelect: { tabID in
                        Task { await environment.selectTab(areaID: area.id, tabID: tabID) }
                    },
                    onClose: { tabID in
                        Task { await environment.closeTab(areaID: area.id, tabID: tabID) }
                    }
                )
                Divider()
                tabContent(area: area)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "No focused tab area",
                    systemImage: "rectangle.split.3x1",
                    description: Text("Open or focus a tab area on the desktop.")
                )
            }
        }
    }

    @ViewBuilder
    private func tabContent(area: TabArea) -> some View {
        if let activeID = area.activeTabID, let tab = area.tabs.first(where: { $0.id == activeID }) {
            TabContentView(tab: tab)
        } else if area.tabs.isEmpty {
            VStack(spacing: Theme.Spacing.sm) {
                Text("No tabs")
                    .font(.title3.weight(.semibold))
                Text("Tap + to open a terminal tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No active tab",
                systemImage: "square.dashed",
                description: Text("Select a tab above to view its content.")
            )
        }
    }

    private func failureView(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Couldn't load workspace.")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Button("Try again") {
                Task { await environment.refreshWorkspace() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TabStrip: View {
    let area: TabArea
    let onSelect: (String) -> Void
    let onClose: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(area.tabs) { tab in
                    TabPill(
                        tab: tab,
                        isActive: tab.id == area.activeTabID,
                        onTap: { onSelect(tab.id) },
                        onClose: { onClose(tab.id) }
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Palette.surface)
    }
}

private struct TabPill: View {
    let tab: MuxyProtocol.Tab
    let isActive: Bool
    let onTap: () -> Void
    let onClose: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon(for: tab.kind))
                    .font(.caption)
                Text(tab.title)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(isActive ? Theme.Palette.accent.opacity(0.2) : Color.clear)
            .foregroundStyle(isActive ? Theme.Palette.accent : Color.primary)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(isActive ? Theme.Palette.accent : Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onClose()
            } label: {
                Label("Close tab", systemImage: "xmark")
            }
        }
    }

    private func icon(for kind: TabKind) -> String {
        switch kind {
        case .terminal: return "terminal"
        case .vcs: return "arrow.triangle.branch"
        case .editor: return "doc.text"
        case .diffViewer: return "rectangle.split.2x1"
        }
    }
}

private struct TabContentView: View {
    let tab: MuxyProtocol.Tab

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: placeholderIcon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(tab.title)
                .font(.title3.weight(.semibold))
            Text(placeholderMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholderIcon: String {
        switch tab.kind {
        case .terminal: return "terminal"
        case .vcs: return "arrow.triangle.branch"
        case .editor: return "doc.text"
        case .diffViewer: return "rectangle.split.2x1"
        }
    }

    private var placeholderMessage: String {
        switch tab.kind {
        case .terminal: return "Terminal rendering arrives in Phase 8."
        case .vcs, .editor, .diffViewer: return "This tab kind isn't supported on mobile yet."
        }
    }
}

#Preview {
    NavigationStack {
        WorkspaceScreen(deviceID: "preview", projectID: "p1")
    }
    .environment(AppEnvironment())
    .environment(AppRouter())
}
