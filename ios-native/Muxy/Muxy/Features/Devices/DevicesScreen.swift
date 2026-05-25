import SwiftUI

struct DevicesScreen: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        List {
            Section {
                ContentUnavailableView(
                    "No Devices",
                    systemImage: "desktopcomputer",
                    description: Text("Add a Muxy desktop to get started.")
                )
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Devices")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    router.present(.settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.present(.addDevice)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add device")
            }
        }
    }
}

#Preview {
    NavigationStack {
        DevicesScreen()
    }
    .environment(AppEnvironment())
    .environment(AppRouter())
}
