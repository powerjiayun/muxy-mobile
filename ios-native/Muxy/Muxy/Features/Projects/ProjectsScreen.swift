import SwiftUI

struct ProjectsScreen: View {
    let deviceID: String

    var body: some View {
        List {
            ContentUnavailableView(
                "Projects load in Phase 6",
                systemImage: "folder",
                description: Text("Device: \(deviceID)")
            )
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Projects")
    }
}

#Preview {
    NavigationStack {
        ProjectsScreen(deviceID: "preview")
    }
    .environment(AppEnvironment())
    .environment(AppRouter())
}
