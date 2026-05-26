import MuxyCore
import SwiftUI

struct ProjectsScreen: View {
    let deviceID: String

    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    private var device: DeviceRecord? {
        environment.devices.first { $0.id == deviceID }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                if let device {
                    Text("Connected to \(device.label)")
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("\(device.host):\(device.port)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Project list arrives in Phase 6")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .navigationTitle("Projects")
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
}

#Preview {
    NavigationStack {
        ProjectsScreen(deviceID: "preview")
    }
    .environment(AppEnvironment())
    .environment(AppRouter())
}
