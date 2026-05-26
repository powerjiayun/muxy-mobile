import Foundation
import MuxyProtocol
import Observation
import SwiftUI

enum AppRoute: Hashable {
    case projects(deviceID: String)
    case workspace(deviceID: String, projectID: String)
}

struct AddDevicePrefill: Hashable {
    let label: String
    let host: String
    let port: Int
    let serviceName: String?
}

enum AppSheet: Hashable, Identifiable {
    case addDevice(prefill: AddDevicePrefill?)
    case scanPair
    case settings
    case paywall

    var id: String {
        switch self {
        case .addDevice: return "addDevice"
        case .scanPair: return "scanPair"
        case .settings: return "settings"
        case .paywall: return "paywall"
        }
    }
}

@Observable
final class AppRouter {
    var path: [AppRoute] = []
    var sheet: AppSheet?
    var pendingScanResult: PairURIPayload?

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
