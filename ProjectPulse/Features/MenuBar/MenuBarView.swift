import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dashboardController: DashboardWindowController

    var body: some View {
        VStack(spacing: 0) {
            statusHeader
            Divider()
            todaySection
            Divider()
            sessionControlSection
            Divider()
            PanelButton("Open Dashboard") {
                dashboardController.open(appState: appState)
            }
            PanelButton("Quit Project Pulse") {
                NSApplication.shared.terminate(nil)
            }
        }
        .frame(width: 240)
    }

    private var statusHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(appState.sessionState.indicatorColor)
                .frame(width: 7, height: 7)
            Text(appState.sessionState.statusLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            todayDurationText
            let topApps = appState.todayAppTotals.prefix(3)
            if !topApps.isEmpty {
                Text("Top Apps")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
                ForEach(Array(topApps)) { app in
                    HStack {
                        Text(app.appName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(DurationTextFormatter.string(from: app.totalDuration))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var todayDurationText: some View {
        switch appState.sessionState {
        case .active:
            if let runStart = appState.sessionActiveRunStartedAt {
                let elapsed = appState.liveClockTick.timeIntervalSince(runStart)
                let total = appState.todayTotalDuration + appState.sessionAccumulatedDuration + elapsed
                Text("Today: \(DurationTextFormatter.string(from: total))")
                    .font(.subheadline)
                    .monospacedDigit()
            } else {
                let total = appState.todayTotalDuration + appState.sessionAccumulatedDuration
                Text("Today: \(DurationTextFormatter.string(from: total))")
                    .font(.subheadline)
                    .monospacedDigit()
            }
        case .paused:
            let total = appState.todayTotalDuration + appState.sessionAccumulatedDuration
            Text("Today: \(DurationTextFormatter.string(from: total))")
                .font(.subheadline)
                .monospacedDigit()
        case .idle:
            let duration = appState.todayTotalDuration
            Text("Today: \(duration > 0 ? DurationTextFormatter.string(from: duration) : "No data yet")")
                .font(.subheadline)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var sessionControlSection: some View {
        switch appState.sessionState {
        case .idle:
            PanelButton("Start Session") { appState.startSession() }
        case .active:
            PanelButton("Pause Session") { appState.pauseSession() }
            PanelButton("End Session") { appState.endSession() }
        case .paused:
            PanelButton("Resume Session") { appState.resumeSession() }
            PanelButton("End Session") { appState.endSession() }
        }
    }
}

private struct PanelButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private extension SessionState {
    var indicatorColor: Color {
        switch self {
        case .idle:   return Color.secondary
        case .active: return Color.green
        case .paused: return Color.orange
        }
    }
}
