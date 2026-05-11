import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dashboardController: DashboardWindowController
    @EnvironmentObject private var updaterService: UpdaterService

    var body: some View {
        VStack(spacing: 0) {
            statusHeader
            Divider()
            todaySection
            sessionAppsSection
            Divider()
            sessionControlSection
            Divider()
            actionsSection
        }
        .padding(.vertical, 4)
        .frame(width: 260)
    }

    // MARK: - Status

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

    // MARK: - Today

    private var todaySection: some View {
        VStack(spacing: 3) {
            SectionLabel("TODAY")
            todayDurationText
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var todayDurationText: some View {
        switch appState.sessionState {
        case .active:
            if let runStart = appState.sessionActiveRunStartedAt {
                let elapsed = appState.liveClockTick.timeIntervalSince(runStart)
                let total = appState.todayTotalDuration + appState.sessionAccumulatedDuration + elapsed
                Text(DurationTextFormatter.string(from: total))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            } else {
                let total = appState.todayTotalDuration + appState.sessionAccumulatedDuration
                Text(DurationTextFormatter.string(from: total))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
        case .paused, .pausedDueToInactivity:
            let total = appState.todayTotalDuration + appState.sessionAccumulatedDuration
            Text(DurationTextFormatter.string(from: total))
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
        case .idle:
            let duration = appState.todayTotalDuration
            Text(duration > 0 ? DurationTextFormatter.string(from: duration) : "No data yet")
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }

    // MARK: - This Session Apps

    @ViewBuilder
    private var sessionAppsSection: some View {
        let sessionApps = appState.currentSessionAppTotals.prefix(3)
        if !sessionApps.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel("THIS SESSION")
                ForEach(Array(sessionApps)) { app in
                    HStack {
                        Text(app.appName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text(DurationTextFormatter.string(from: app.totalDuration))
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var sessionControlSection: some View {
        VStack(spacing: 0) {
            switch appState.sessionState {
            case .idle:
                PanelButton("Start Session") { appState.startSession() }
            case .active:
                PanelButton("Pause Session") { appState.pauseSession() }
                PanelButton("End Session") { appState.endSession() }
            case .paused, .pausedDueToInactivity:
                PanelButton("Resume Session") { appState.resumeSession() }
                PanelButton("End Session") { appState.endSession() }
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 0) {
            PanelButton("Open Dashboard") {
                dashboardController.open(appState: appState, updaterService: updaterService)
            }
            PanelButton("Quit Veira") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

// MARK: - Supporting Views

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.tertiary)
            .kerning(0.4)
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

// MARK: - SessionState helpers

private extension SessionState {
    var indicatorColor: Color {
        switch self {
        case .idle:                  return Color.secondary
        case .active:                return Color.green
        case .paused:                return Color.orange
        case .pausedDueToInactivity: return Color.yellow
        }
    }
}
