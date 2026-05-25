import Foundation
import Observation

@Observable
final class AppEnvironment {
    enum Bootstrap {
        case onboarding
        case devices
    }

    var bootstrap: Bootstrap = .onboarding
    var useNerdFont: Bool = false
    var autoFocusTerminal: Bool = true
    var demoMode: Bool = false

    func markOnboardingComplete() {
        bootstrap = .devices
    }
}
