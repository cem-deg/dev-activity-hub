import SwiftUI

@main
struct ProjectPulseApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var dashboardController = DashboardWindowController()

    var body: some Scene {
        MenuBarExtra("Project Pulse", systemImage: "circle.fill") {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(dashboardController)
        }
        .menuBarExtraStyle(.window)
    }
}
