import SwiftUI

struct WorkspaceScreen: View {
    let deviceID: String
    let projectID: String

    var body: some View {
        ContentUnavailableView(
            "Workspace arrives in Phase 7",
            systemImage: "rectangle.split.3x1",
            description: Text("Device: \(deviceID)\nProject: \(projectID)")
        )
        .navigationTitle("Workspace")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        WorkspaceScreen(deviceID: "preview", projectID: "p1")
    }
    .environment(AppEnvironment())
    .environment(AppRouter())
}
