import AppKit
import SwiftUI
import UserNotifications

@main
struct ProjectPulseApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var dashboardController = DashboardWindowController()
    @StateObject private var onboardingController = OnboardingWindowController()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        MenuBarExtra("Veira", image: "MenuBarIcon") {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(dashboardController)
                .task {
                    guard !appState.hasCompletedOnboarding else { return }
                    onboardingController.open(appState: appState)
                }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Onboarding Window

private final class OnboardingWindowController: NSObject, ObservableObject, NSWindowDelegate {
    private var window: NSWindow?
    private weak var appState: AppState?

    func open(appState: AppState) {
        self.appState = appState
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Welcome to Veira"
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.contentView = NSHostingView(
            rootView: OnboardingView().environmentObject(appState)
        )
        newWindow.delegate = self
        newWindow.makeKeyAndOrderFront(nil)
        window = newWindow
    }

    func windowWillClose(_ notification: Notification) {
        // Treat dismissal via the close button the same as "Not now".
        appState?.markOnboardingComplete()
        window = nil
    }
}

// MARK: - Notification Delegate

private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
