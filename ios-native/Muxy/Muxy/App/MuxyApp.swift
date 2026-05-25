import SwiftUI

@main
struct MuxyApp: App {
    @State private var environment = AppEnvironment()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(router)
                .task {
                    await environment.start()
                }
        }
    }
}
