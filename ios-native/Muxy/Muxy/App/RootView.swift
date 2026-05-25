import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var bindableRouter = router

        NavigationStack(path: $bindableRouter.path) {
            rootScreen
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .sheet(item: $bindableRouter.sheet) { sheet in
            sheetView(for: sheet)
        }
    }

    @ViewBuilder
    private var rootScreen: some View {
        switch environment.bootstrap {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Palette.background.ignoresSafeArea())
        case .onboarding:
            OnboardingScreen()
        case .devices:
            DevicesScreen()
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .projects(let deviceID):
            ProjectsScreen(deviceID: deviceID)
        case .workspace(let deviceID, let projectID):
            WorkspaceScreen(deviceID: deviceID, projectID: projectID)
        }
    }

    @ViewBuilder
    private func sheetView(for sheet: AppSheet) -> some View {
        switch sheet {
        case .addDevice:
            NavigationStack {
                AddDeviceScreen()
            }
        case .scanPair:
            NavigationStack {
                ScanPairScreen()
            }
        case .settings:
            NavigationStack {
                SettingsScreen()
            }
        case .paywall:
            NavigationStack {
                PaywallScreen()
            }
        }
    }
}
