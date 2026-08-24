import Foundation
import ServiceManagement

struct LaunchAtLoginStatus: Equatable {
    let isEnabled: Bool
    let message: String?
}

protocol LaunchAtLoginControlling: AnyObject {
    var status: LaunchAtLoginStatus { get }
    func setEnabled(_ enabled: Bool) -> LaunchAtLoginStatus
}

/// Uses Apple's modern main-app login item API; failures are surfaced without fallback hacks.
final class LaunchAtLoginController: LaunchAtLoginControlling {
    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    var status: LaunchAtLoginStatus {
        presentation(for: service.status)
    }

    func setEnabled(_ enabled: Bool) -> LaunchAtLoginStatus {
        do {
            if enabled {
                guard service.status == .notRegistered || service.status == .notFound else {
                    return status
                }
                try service.register()
            } else {
                guard service.status == .enabled || service.status == .requiresApproval else {
                    return status
                }
                try service.unregister()
            }
            return status
        } catch {
            return LaunchAtLoginStatus(
                isEnabled: status.isEnabled,
                message: "Launch at login unavailable: \(error.localizedDescription)"
            )
        }
    }

    private func presentation(for status: SMAppService.Status) -> LaunchAtLoginStatus {
        switch status {
        case .enabled:
            return LaunchAtLoginStatus(isEnabled: true, message: nil)
        case .requiresApproval:
            return LaunchAtLoginStatus(
                isEnabled: true,
                message: "Approval required in System Settings → Login Items."
            )
        case .notRegistered:
            return LaunchAtLoginStatus(isEnabled: false, message: nil)
        case .notFound:
            return LaunchAtLoginStatus(
                isEnabled: false,
                message: "Install WhyWait in Applications to enable launch at login."
            )
        @unknown default:
            return LaunchAtLoginStatus(
                isEnabled: false,
                message: "Launch-at-login status is unavailable."
            )
        }
    }
}
