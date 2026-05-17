import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dashboardController: DashboardWindowController
    @EnvironmentObject private var updaterService: UpdaterService

    // Desk title entry inline flow
    @State private var showDeskTitleEntry = false
    @State private var deskTitleText = ""
    @State private var deskTargetMinutes: Int = 0   // 0 = no target
    @State private var deskProjectText = ""

    private static let targetOptions: [(label: String, minutes: Int)] = [
        ("No target", 0), ("15 min", 15), ("25 min", 25), ("30 min", 30),
        ("45 min", 45), ("1 hour", 60), ("90 min", 90), ("2 hours", 120),
    ]

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
        .onChange(of: appState.sessionState) { _, newState in
            if newState != .idle {
                resetDeskEntry()
            }
        }
        .onChange(of: appState.selectedStartMode) { _, newMode in
            if newMode != .focus {
                resetDeskEntry()
            }
        }
    }

    // MARK: - Status

    private var statusHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(appState.sessionState.indicatorColor)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(appState.sessionState.statusLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                // Show desk session title under the status label when active
                if appState.activeSessionMode == .focus,
                   let title = appState.activeFocusTitle {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                if let project = appState.activeSessionProjectName, !project.isEmpty {
                    Text(project)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
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
        case .active, .paused, .pausedDueToInactivity:
            let total = appState.todayTotalDuration + appState.currentSessionTodayDuration
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
    // Hidden during desk sessions (no per-app breakdown for desk work).

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
                if showDeskTitleEntry {
                    deskTitleEntrySection
                } else {
                    modeSelector
                    PanelButton("Start Session") { handleStartTap() }
                }
            case .active:
                PanelButton("Pause Session") { appState.pauseSession() }
                PanelButton("End Session") { appState.endSession() }
            case .paused, .pausedDueToInactivity:
                PanelButton("Resume Session") { appState.resumeSession() }
                PanelButton("End Session") { appState.endSession() }
            }
        }
    }

    // Compact two-option mode toggle: Computer | Desk
    private var modeSelector: some View {
        HStack(spacing: 1) {
            modeTab("Computer", for: .appTracking)
            modeTab("Desk", for: .focus)
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.10)))
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private func modeTab(_ label: String, for mode: SessionMode) -> some View {
        Button { appState.selectedStartMode = mode } label: {
            Text(label)
                .font(.caption)
                .fontWeight(appState.selectedStartMode == mode ? .semibold : .regular)
                .foregroundStyle(appState.selectedStartMode == mode ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background {
                    if appState.selectedStartMode == mode {
                        RoundedRectangle(cornerRadius: 5).fill(.secondary.opacity(0.2))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func handleStartTap() {
        switch appState.selectedStartMode {
        case .appTracking:
            appState.startSession()
        case .focus:
            showDeskTitleEntry = true
        }
    }

    // Inline title entry shown when Desk mode is selected and Start Session is tapped.
    private var deskTitleEntrySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Full-width button row so the tap target is always reliably hit.
            Button {
                resetDeskEntry()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                    Text("Back")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("What are you working on?")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            TextField("e.g. Math homework", text: $deskTitleText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.secondary.opacity(0.12))
                )
                .padding(.horizontal, 14)
                .onSubmit { confirmStartDesk() }

            // Project / label (optional)
            TextField("Project (optional)", text: $deskProjectText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.10)))
                .padding(.horizontal, 14)
                .padding(.top, 6)

            // Target duration picker
            HStack(spacing: 6) {
                Text("Target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $deskTargetMinutes) {
                    ForEach(Self.targetOptions, id: \.minutes) { option in
                        Text(option.label).tag(option.minutes)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(.caption)
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 2)

            PanelButton("Start Desk Session") { confirmStartDesk() }
                .padding(.top, 4)
        }
    }

    private func confirmStartDesk() {
        let target: TimeInterval? = deskTargetMinutes > 0 ? Double(deskTargetMinutes) * 60 : nil
        appState.startFocusSession(title: deskTitleText, targetDuration: target, projectName: deskProjectText)
        dashboardController.open(appState: appState, updaterService: updaterService)
        resetDeskEntry()
    }

    private func resetDeskEntry() {
        showDeskTitleEntry = false
        deskTitleText = ""
        deskTargetMinutes = 0
        deskProjectText = ""
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 0) {
            PanelButton("Open Dashboard") {
                dashboardController.open(appState: appState, updaterService: updaterService)
            }
            PanelButton("Quit Veira") {
                appState.prepareForQuit()
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
