import ServiceManagement

final class LaunchAtLoginService: ObservableObject {
    @Published private(set) var isEnabled: Bool

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func toggle() {
        isEnabled ? unregister() : register()
    }

    func register() {
        try? SMAppService.mainApp.register()
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func unregister() {
        try? SMAppService.mainApp.unregister()
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
