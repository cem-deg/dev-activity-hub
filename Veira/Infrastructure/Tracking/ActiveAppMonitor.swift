import AppKit

final class ActiveAppMonitor {
    var onEvent: ((ActivityEvent) -> Void)?

    private var observer: Any?

    func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication else { return }
            self?.handle(app)
        }

        if let current = NSWorkspace.shared.frontmostApplication {
            handle(current)
        }
    }

    func stop() {
        guard let observer else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(observer)
        self.observer = nil
    }

    private func handle(_ app: NSRunningApplication) {
        let event = ActivityEvent(
            appName: app.localizedName ?? "Unknown",
            bundleIdentifier: app.bundleIdentifier ?? "unknown.bundle",
            timestamp: Date()
        )
        onEvent?(event)
        print("[ActiveAppMonitor] \(event.appName) — \(event.bundleIdentifier)")
    }

    deinit {
        stop()
    }
}
