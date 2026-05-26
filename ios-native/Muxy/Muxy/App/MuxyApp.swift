import SwiftUI

@main
struct MuxyApp: App {
    @State private var environment = AppEnvironment()
    @State private var router = AppRouter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(router)
                .task {
                    await environment.start()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    Task {
                        switch newPhase {
                        case .background:
                            await environment.suspend()
                        case .active:
                            await environment.resume()
                        case .inactive:
                            break
                        @unknown default:
                            break
                        }
                    }
                }
        }
    }
}
