import AppKit
import SwiftUI

final class DashboardWindowController: NSObject, ObservableObject, NSWindowDelegate {
    private var window: NSWindow?

    func open(appState: AppState, updaterService: UpdaterService) {
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
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
        newWindow.makeKeyAndOrderFront(nil)
        window = newWindow
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
