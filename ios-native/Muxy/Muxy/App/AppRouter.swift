import Foundation
import Observation
import SwiftUI

enum AppRoute: Hashable {
    case projects(deviceID: String)
    case workspace(deviceID: String, projectID: String)
}

enum AppSheet: Hashable, Identifiable {
    case addDevice
    case scanPair
    case settings
    case paywall

    var id: Self { self }
}

@Observable
final class AppRouter {
    var path: [AppRoute] = []
    var sheet: AppSheet?

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func present(_ sheet: AppSheet) {
        self.sheet = sheet
    }

    func dismissSheet() {
        sheet = nil
    }

    func popToRoot() {
        path.removeAll()
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}
