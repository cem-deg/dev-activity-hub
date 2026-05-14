import AppKit
import SwiftUI

final class DashboardWindowController: NSObject, ObservableObject, NSWindowDelegate {
    private var window: NSWindow?

    func open(appState: AppState, updaterService: UpdaterService) {
        if let existing = window {
            bringToFront(existing)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Dashboard — Veira"
        newWindow.center()
        newWindow.contentView = NSHostingView(
            rootView: DashboardView()
                .environmentObject(appState)
                .environmentObject(updaterService)
        )
        newWindow.delegate = self
        window = newWindow
        bringToFront(newWindow)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    private func bringToFront(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)

        // MenuBarExtra closes after the button action returns; reassert focus on
        // the next run loop so the dashboard is not left behind the previous app.
        DispatchQueue.main.async {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
