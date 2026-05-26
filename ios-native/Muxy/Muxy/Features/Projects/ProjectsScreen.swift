import MuxyCore
import MuxyProtocol
import SwiftUI

struct ProjectsScreen: View {
    let deviceID: String

    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    private var device: DeviceRecord? {
        environment.devices.first { $0.id == deviceID }
    }

    var body: some View {
        Group {
            switch environment.projectsState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .projects(let projects) where projects.isEmpty:
                emptyState
            case .projects(let projects):
                projectList(projects)
            case .failed(let message):
                failureView(message)
            }
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .navigationTitle(device?.label ?? "Projects")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Disconnect") {
                    Task {
                        await environment.disconnect()
                        router.popToRoot()
                    }
                }
            }
        }
        .onChange(of: environment.connectionState) { _, newState in
            if case .idle = newState {
                router.popToRoot()
            }
            if case .failed(let reason) = newState, case .needsRepair = reason {
                router.popToRoot()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("No projects yet")
                .font(.title3.weight(.semibold))
            Text("Open a project on your desktop to see it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failureView(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Couldn't load projects.")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Button("Try again") {
                Task { await environment.refreshProjects() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func projectList(_ projects: [Project]) -> some View {
        let sorted = projects.sorted { $0.sortOrder < $1.sortOrder }
        return List {
            ForEach(sorted) { project in
                Button {
                    router.push(.workspace(deviceID: deviceID, projectID: project.id))
                } label: {
                    ProjectRow(
                        project: project,
                        logoData: environment.projectLogos[project.id]
                    )
                    .onAppear {
                        if project.logo != nil {
                            environment.requestLogo(projectID: project.id)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Theme.Palette.surface)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.background.ignoresSafeArea())
        .refreshable {
            await environment.refreshProjects()
        }
    }
}

private struct ProjectRow: View {
    let project: Project
    let logoData: Data?

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            logoView
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(project.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var logoView: some View {
        if let logoData, let uiImage = UIImage(data: logoData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: "folder.fill")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
        }
    }
}

#Preview {
    NavigationStack {
        ProjectsScreen(deviceID: "preview")
    }
    .environment(AppEnvironment())
    .environment(AppRouter())
}
