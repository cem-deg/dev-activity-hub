import Charts
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var updaterService: UpdaterService
    @State private var isShowingWeeklyDetails = false
    @State private var isShowingSettings = false
    @State private var isShowingDeskTimer = false
    @State private var isShowingWeeklyReview = false
    @State private var projectDetailName: String?    // drives ProjectDetailView
    @State private var projectFilter: String?        // filters TodaySummarySection session list
    @State private var renamingSession: TrackedSession?
    @State private var renameText = ""
    @State private var labelingSession: TrackedSession?
    @State private var labelText = ""

    var body: some View {
        ZStack {
            dashboardContent
                .disabled(renamingSession != nil || labelingSession != nil)

            if let renamingSession {
                RenameSessionDialog(
                    session: renamingSession,
                    title: $renameText,
                    onCancel: cancelRename,
                    onDone: commitRename
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            if let labelingSession {
                ProjectLabelDialog(
                    session: labelingSession,
                    labelText: $labelText,
                    onCancel: cancelLabel,
                    onDone: commitLabel
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: renamingSession?.id)
        .animation(.easeInOut(duration: 0.15), value: labelingSession?.id)
        .onAppear {
            // Auto-show desk timer when dashboard is opened during an active desk session.
            if appState.activeSessionMode == .focus && appState.sessionState != .idle {
                isShowingDeskTimer = true
            }
        }
        .onChange(of: appState.sessionState) { oldState, newState in
            if newState == .idle {
                isShowingDeskTimer = false
            } else if oldState == .idle && appState.activeSessionMode == .focus {
                // Handles starting a desk session while the dashboard window already exists.
                isShowingDeskTimer = true
            }
        }
    }

    @ViewBuilder
    private var dashboardContent: some View {
        if let completed = appState.lastCompletedSession, appState.sessionState == .idle {
            SessionCompletionView(session: completed, onDismiss: appState.clearLastCompletedSession)
        } else if let name = projectDetailName {
            ProjectDetailView(
                projectName: name,
                onBack: { projectDetailName = nil },
                onFilterToday: { showProjectFilter(name) }
            )
        } else if isShowingDeskTimer {
            DeskTimerView(onBack: { isShowingDeskTimer = false })
        } else if isShowingWeeklyReview {
            WeeklyReviewView(onBack: { isShowingWeeklyReview = false }, onProjectTap: openProjectDetail)
        } else if isShowingSettings {
            SettingsView(onBack: { isShowingSettings = false })
        } else if isShowingWeeklyDetails {
            WeeklyDetailsView(
                isShowing: $isShowingWeeklyDetails,
                onRenameSession: beginRename,
                onLabelSession: beginLabel,
                onProjectTap: openProjectDetail
            )
            .environmentObject(appState)
        } else {
            mainDashboard
        }
    }

    private func openProjectDetail(_ name: String) {
        projectDetailName = name
    }

    private func showProjectFilter(_ name: String) {
        projectFilter = name
        projectDetailName = nil
        isShowingWeeklyReview = false
        isShowingWeeklyDetails = false
        isShowingSettings = false
        isShowingDeskTimer = false
    }

    private var mainDashboard: some View {
        VStack(spacing: 0) {
            // Sticky desk session banner.
            if appState.activeSessionMode == .focus && appState.sessionState != .idle {
                DeskSessionBanner { isShowingDeskTimer = true }
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }
            // Project filter chip — shown when a project filter is active.
            if let f = projectFilter {
                HStack(spacing: 6) {
                    Text("Today Sessions:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(f)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Button { projectFilter = nil } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button { openProjectDetail(f) } label: {
                        Text("Project Details")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.10)))
                .padding(.horizontal, 32)
                .padding(.top, appState.activeSessionMode == .focus ? 8 : 16)
                .padding(.bottom, 8)
            }
            ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    let streak = appState.currentStreakDays
                    Text(streak > 0 ? "\(streak) Day Streak 🔥" : "Start your streak today")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(streak > 0 ? .primary : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.secondary.opacity(0.15)))
                    Spacer()
                    Button {
                        isShowingSettings = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "gear")
                                .font(.caption)
                            Text("Settings")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.secondary.opacity(0.10))
                        )
                    }
                    .buttonStyle(.plain)
                }
                SessionStatusCard()
                TodaySummarySection(
                    onRenameSession: beginRename,
                    onLabelSession: beginLabel,
                    onProjectTap: openProjectDetail,
                    projectFilter: projectFilter
                )
                QuickInsightsSection()
                AppBreakdownSection(projectFilter: projectFilter)
                WeeklySummarySection(isShowingWeeklyDetails: $isShowingWeeklyDetails, isShowingWeeklyReview: $isShowingWeeklyReview)
            }
            .padding(32)
            } // ScrollView
        } // outer VStack
        .frame(minWidth: 640, minHeight: 480)
    }

    private func beginRename(_ session: TrackedSession) {
        renameText = session.title ?? session.displayTitle
        renamingSession = session
    }

    private func cancelRename() {
        renamingSession = nil
        renameText = ""
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let renamingSession, !trimmed.isEmpty {
            appState.renameSession(id: renamingSession.id, newTitle: trimmed)
        }
        cancelRename()
    }

    func beginLabel(_ session: TrackedSession) {
        labelText = session.projectName ?? ""
        labelingSession = session
    }

    private func cancelLabel() {
        labelingSession = nil
        labelText = ""
    }

    private func commitLabel() {
        if let labelingSession {
            appState.setSessionProject(id: labelingSession.id, projectName: labelText)
        }
        cancelLabel()
    }
}

// MARK: - Rename Session Dialog

private struct RenameSessionDialog: View {
    let session: TrackedSession
    @Binding var title: String
    let onCancel: () -> Void
    let onDone: () -> Void
    @FocusState private var isTitleFocused: Bool

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Rename Desk Session")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Update the label shown in your session history.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("Session title", text: $title)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.secondary.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary.opacity(0.18), lineWidth: 1)
                    )
                    .focused($isTitleFocused)
                    .onSubmit {
                        if canSave {
                            onDone()
                        }
                    }

                HStack(spacing: 8) {
                    Spacer()
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.plain)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.secondary.opacity(0.10))
                        )
                    Button("Done", action: onDone)
                        .buttonStyle(.plain)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(canSave ? Color.accentColor : Color.secondary.opacity(0.18))
                        )
                        .disabled(!canSave)
                }
            }
            .padding(20)
            .frame(width: 360)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 14)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if title.isEmpty {
                title = session.title ?? session.displayTitle
            }
            isTitleFocused = true
        }
    }
}

// MARK: - Today Summary

private struct TodaySummarySection: View {
    @EnvironmentObject private var appState: AppState
    @State private var showAllSessions = false
    let onRenameSession: (TrackedSession) -> Void
    let onLabelSession: (TrackedSession) -> Void
    var onProjectTap: ((String) -> Void)? = nil
    var projectFilter: String? = nil

    private static let defaultSessionLimit = 1

    private var sessions: [TrackedSession] {
        let all = Array((appState.todayRecord?.sessions ?? []).reversed())
        if let f = projectFilter, !f.isEmpty {
            return all.filter { $0.projectName == f }
        }
        return all
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today Summary")
                .font(.title3)
                .fontWeight(.semibold)

            if sessions.isEmpty {
                emptyState
            } else {
                summaryStats
                sessionList
            }
        }
    }

    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.secondary.opacity(0.12))
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .overlay(
                Text("No sessions today")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            )
    }

    private var summaryStats: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(DurationTextFormatter.string(from: appState.todayTotalDuration))
                    .font(.title)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text("Total Time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(sessions.count)")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text(sessions.count == 1 ? "session" : "sessions")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.12))
        )
    }

    private var sessionList: some View {
        let limit = Self.defaultSessionLimit
        let needsToggle = sessions.count > limit
        let visible = needsToggle && !showAllSessions ? Array(sessions.prefix(limit)) : sessions

        return VStack(spacing: 6) {
            ForEach(visible, id: \.id) { session in
                SessionRow(session: session, onRename: onRenameSession, onLabel: onLabelSession, onProjectTap: onProjectTap)
            }
            if needsToggle {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showAllSessions.toggle()
                    }
                } label: {
                    Text(showAllSessions ? "Show less" : "Show more sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
            }
        }
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let session: TrackedSession
    var onRename: ((TrackedSession) -> Void)? = nil
    var onLabel: ((TrackedSession) -> Void)? = nil
    var onProjectTap: ((String) -> Void)? = nil
    @State private var isExpanded = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    var body: some View {
        if session.isFocusSession {
            focusRow
        } else {
            appTrackingRow
        }
    }

    // MARK: Desk session row

    private var focusRow: some View {
        let start = Self.timeFormatter.string(from: session.startedAt)
        let end   = Self.timeFormatter.string(from: session.endedAt)
        let duration = session.segmentDuration

        return VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Desk")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .kerning(0.3)
                        if let proj = session.projectName, !proj.isEmpty {
                            if let handler = onProjectTap {
                                Button { handler(proj) } label: {
                                    Text(proj)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                                }
                                .buttonStyle(.plain)
                                .help("View \(proj)")
                            } else {
                                Text(proj)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(.secondary.opacity(0.12)))
                            }
                        }
                    }
                    Text(session.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(start) – \(end)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(DurationTextFormatter.string(from: duration))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                    HStack(spacing: 6) {
                        if let handler = onLabel {
                            Button { handler(session) } label: {
                                Image(systemName: "tag")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .padding(4)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(session.projectName == nil ? "Assign project" : "Edit project")
                        }
                        if let handler = onRename {
                            Button {
                                handler(session)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "pencil")
                                        .font(.caption2)
                                    Text("Rename")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.secondary.opacity(0.10))
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Rename desk session")
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.secondary.opacity(0.08))
        )
    }

    // MARK: App tracking session row (existing behavior)

    private var appTrackingRow: some View {
        let start = Self.timeFormatter.string(from: session.startedAt)
        let end   = Self.timeFormatter.string(from: session.endedAt)
        let duration = session.segmentDuration
        let apps = session.appSummary
        let breakdown = session.perAppDurations
        let hasTimeline = session.endedAt > session.startedAt && !session.segments.isEmpty

        return VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    appTrackingSummary(
                        start: start,
                        end: end,
                        duration: duration,
                        apps: apps,
                        breakdown: breakdown
                    )
                }
                .buttonStyle(.plain)

                // Project capsule button (if project is set and handler exists)
                if let proj = session.projectName, !proj.isEmpty, let handler = onProjectTap {
                    Button { handler(proj) } label: {
                        Text(proj)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("View \(proj)")
                }
                if let handler = onLabel {
                    Button { handler(session) } label: {
                        Image(systemName: session.projectName == nil ? "tag" : "tag.fill")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(session.projectName == nil ? "Assign project" : "Edit project")
                }
                Spacer(minLength: 12)
            }
            .padding(.top, 8)
            .padding(.bottom, hasTimeline ? 6 : 8)

            if hasTimeline {
                SessionTimelineBar(session: session)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 9)
            }

            if isExpanded && !breakdown.isEmpty {
                Divider()
                    .padding(.horizontal, 12)
                    .opacity(0.6)
                SessionDetailPanel(session: session, breakdown: breakdown)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.secondary.opacity(0.08))
        )
    }

    private func appTrackingSummary(
        start: String,
        end: String,
        duration: TimeInterval,
        apps: String,
        breakdown: [(bundleIdentifier: String, appName: String, duration: TimeInterval)]
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(DurationTextFormatter.string(from: duration))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                HStack(spacing: 8) {
                    Text("\(start) – \(end)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !apps.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(apps)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            if !breakdown.isEmpty {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .padding(.leading, 12)
    }
}

private struct SessionTimelineBar: View {
    let session: TrackedSession
    @State private var hoveredEntryID: Int? = nil

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private struct Entry: Identifiable {
        enum Kind {
            case app(appName: String, bundleIdentifier: String)
            case gap
        }

        let id: Int
        let kind: Kind
        let startTime: Date
        let endTime: Date

        var duration: TimeInterval {
            endTime.timeIntervalSince(startTime)
        }

        var title: String {
            switch kind {
            case .app(let appName, _): return appName
            case .gap: return "No tracked activity"
            }
        }

        var bundleIdentifier: String? {
            switch kind {
            case .app(_, let bundleIdentifier): return bundleIdentifier
            case .gap: return nil
            }
        }

        var isGap: Bool {
            if case .gap = kind { return true }
            return false
        }
    }

    private var entries: [Entry] {
        Self.entries(for: session)
    }

    private var totalDuration: TimeInterval {
        entries.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        let timelineEntries = entries
        let total = totalDuration
        let hoveredEntry = timelineEntries.first(where: { $0.id == hoveredEntryID })

        VStack(alignment: .leading, spacing: 5) {
            // Only render the bar when there is tracked time to show.
            if total > 0 && !timelineEntries.isEmpty {
                GeometryReader { geo in
                    let availableWidth = max(0, geo.size.width)
                    // HStack(spacing:0) with Rectangle segments tiles the full bar width.
                    // Using Rectangle (not RoundedRectangle) for each segment prevents
                    // rounded/oval ends at internal app boundaries. The outer clipShape
                    // rounds only the two outer corners of the whole bar.
                    HStack(spacing: 0) {
                        ForEach(timelineEntries) { entry in
                            let w = availableWidth * CGFloat(entry.duration / total)
                            Rectangle()
                                .fill(Self.color(for: entry))
                                .frame(width: max(0, w))
                                .opacity(hoveredEntryID == nil || hoveredEntryID == entry.id ? 1.0 : 0.45)
                                .help(helpText(for: entry))
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active:
                                        hoveredEntryID = entry.id
                                    case .ended:
                                        if hoveredEntryID == entry.id {
                                            hoveredEntryID = nil
                                        }
                                    }
                                }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                .frame(height: 10)
            }

            Group {
                if let hoveredEntry {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Self.color(for: hoveredEntry))
                            .frame(width: 6, height: 6)
                        Text(hoveredEntry.title)
                            .lineLimit(1)
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(timeRange(for: hoveredEntry))
                            .monospacedDigit()
                        Spacer(minLength: 8)
                        Text(DurationTextFormatter.string(from: hoveredEntry.duration))
                            .monospacedDigit()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text(Self.timeFormatter.string(from: session.startedAt))
                        Spacer()
                        Text(Self.timeFormatter.string(from: session.endedAt))
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                }
            }
            .frame(height: 14)
        }
    }

    private func timeRange(for entry: Entry) -> String {
        "\(Self.timeFormatter.string(from: entry.startTime))-\(Self.timeFormatter.string(from: entry.endTime))"
    }

    private func helpText(for entry: Entry) -> String {
        "\(entry.title) · \(timeRange(for: entry)) · \(DurationTextFormatter.string(from: entry.duration))"
    }

    private static func entries(for session: TrackedSession) -> [Entry] {
        guard session.endedAt > session.startedAt else { return [] }

        let sortedSegments = session.segments
            .compactMap { segment -> ActivitySegment? in
                guard let end = segment.endTime, end > segment.startTime else { return nil }
                return segment
            }
            .sorted { $0.startTime < $1.startTime }

        var result: [Entry] = []
        var nextID = 0

        func appendEntry(kind: Entry.Kind, start: Date, end: Date) {
            guard end > start else { return }
            result.append(Entry(
                id: nextID,
                kind: kind,
                startTime: start,
                endTime: end
            ))
            nextID += 1
        }

        for segment in sortedSegments {
            guard let rawEnd = segment.endTime else { continue }
            let start = max(segment.startTime, session.startedAt)
            let end = min(rawEnd, session.endedAt)
            guard end > start else { continue }

            appendEntry(
                kind: .app(appName: segment.appName, bundleIdentifier: segment.bundleIdentifier),
                start: start,
                end: end
            )
        }

        return result
    }

    private static func color(for entry: Entry) -> Color {
        guard let bundleIdentifier = entry.bundleIdentifier else {
            return .secondary.opacity(0.18)
        }
        return SessionColor.color(for: bundleIdentifier)
    }
}

private struct SessionDetailPanel: View {
    let session: TrackedSession
    let breakdown: [(bundleIdentifier: String, appName: String, duration: TimeInterval)]

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private var segments: [ActivitySegment] {
        session.segments
            .filter { segment in
                guard let end = segment.endTime else { return false }
                return end > segment.startTime
            }
            .sorted { $0.startTime < $1.startTime }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Apps")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)

                ForEach(breakdown, id: \.bundleIdentifier) { entry in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(SessionColor.color(for: entry.bundleIdentifier))
                            .frame(width: 7, height: 7)
                        Text(entry.appName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text(DurationTextFormatter.string(from: entry.duration))
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !segments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Timeline")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)

                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        SegmentDetailRow(segment: segment, timeFormatter: Self.timeFormatter)
                    }
                }
            }
        }
    }
}

private struct SegmentDetailRow: View {
    let segment: ActivitySegment
    let timeFormatter: DateFormatter

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(SessionColor.color(for: segment.bundleIdentifier))
                .frame(width: 4, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(segment.appName)
                    .font(.caption)
                    .lineLimit(1)
                if let endTime = segment.endTime {
                    Text("\(timeFormatter.string(from: segment.startTime))-\(timeFormatter.string(from: endTime))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            Spacer()
            if let duration = segment.duration {
                Text(DurationTextFormatter.string(from: duration))
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private enum SessionColor {
    private static let palette: [Color] = [
        .blue.opacity(0.76),
        .orange.opacity(0.74),
        .teal.opacity(0.74),
        .purple.opacity(0.72),
        .green.opacity(0.70),
        .pink.opacity(0.70),
        .indigo.opacity(0.72),
        .mint.opacity(0.72),
        .yellow.opacity(0.68)
    ]

    static func color(for key: String) -> Color {
        let hash = key.unicodeScalars.reduce(0) { partial, scalar in
            partial &* 31 &+ Int(scalar.value)
        }
        let index = Int(hash.magnitude % UInt(palette.count))
        return palette[index]
    }
}

// MARK: - Session Status Card

private struct SessionStatusCard: View {
    @EnvironmentObject private var appState: AppState
    @State private var showDeskTitleEntry = false
    @State private var deskTitleText = ""
    @State private var deskProjectText = ""
    @State private var deskTargetMinutes: Int = 0
    private static let idleControlWidth: CGFloat = 145

    private static let targetOptions: [(label: String, minutes: Int)] = [
        ("No target", 0), ("15 min", 15), ("25 min", 25), ("30 min", 30),
        ("45 min", 45), ("1 hour", 60), ("90 min", 90), ("2 hours", 120),
    ]

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(appState.sessionState.indicatorColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.sessionState.statusLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let duration = sessionDurationText {
                    Text(duration)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
            }
            Spacer()
            sessionControls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.12))
        )
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

    private var sessionDurationText: String? {
        switch appState.sessionState {
        case .idle:
            return nil
        case .active:
            let elapsed = appState.sessionActiveRunStartedAt.map {
                appState.liveClockTick.timeIntervalSince($0)
            } ?? 0
            return DurationTextFormatter.string(from: appState.sessionAccumulatedDuration + elapsed)
        case .paused, .pausedDueToInactivity:
            return DurationTextFormatter.string(from: appState.sessionAccumulatedDuration)
        }
    }

    @ViewBuilder
    private var sessionControls: some View {
        switch appState.sessionState {
        case .idle:
            if showDeskTitleEntry {
                deskTitleEntryControls
            } else {
                idleStartControls
            }
        case .active:
            HStack(spacing: 6) {
                Button { appState.pauseSession() } label: {
                    Text("Pause")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.15)))
                }
                .buttonStyle(.plain)
                Button { appState.endSession() } label: {
                    Text("End")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        case .paused, .pausedDueToInactivity:
            HStack(spacing: 6) {
                Button { appState.resumeSession() } label: {
                    Text("Resume")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                Button { appState.endSession() } label: {
                    Text("End")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var idleStartControls: some View {
        VStack(spacing: 8) {
            modeSelector
            Button { handleStartTap() } label: {
                Text("Start Session")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.accentColor))
            }
            .buttonStyle(.plain)
        }
        .frame(width: Self.idleControlWidth)
    }

    private var modeSelector: some View {
        HStack(spacing: 1) {
            modeTab("Computer", for: .appTracking)
            modeTab("Desk", for: .focus)
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.10)))
    }

    private func modeTab(_ label: String, for mode: SessionMode) -> some View {
        Button { appState.selectedStartMode = mode } label: {
            Text(label)
                .font(.caption)
                .fontWeight(appState.selectedStartMode == mode ? .semibold : .regular)
                .foregroundStyle(appState.selectedStartMode == mode ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background {
                    if appState.selectedStartMode == mode {
                        RoundedRectangle(cornerRadius: 5).fill(.secondary.opacity(0.2))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var deskTitleEntryControls: some View {
        VStack(alignment: .trailing, spacing: 7) {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            TextField("e.g. Math homework", text: $deskTitleText)
                .textFieldStyle(.plain)
                .font(.caption)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.12)))
                .onSubmit { confirmStartDesk() }

            TextField("Project (optional)", text: $deskProjectText)
                .textFieldStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.09)))

            // Target duration picker
            HStack(spacing: 5) {
                Text("Target")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Picker("", selection: $deskTargetMinutes) {
                    ForEach(Self.targetOptions, id: \.minutes) { option in
                        Text(option.label).tag(option.minutes)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(.caption2)
                Spacer()
            }

            Button { confirmStartDesk() } label: {
                Text("Start Desk Session")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor))
            }
            .buttonStyle(.plain)
        }
        .frame(width: 210)
    }

    private func handleStartTap() {
        switch appState.selectedStartMode {
        case .appTracking:
            appState.startSession()
        case .focus:
            showDeskTitleEntry = true
        }
    }

    private func confirmStartDesk() {
        let target: TimeInterval? = deskTargetMinutes > 0 ? Double(deskTargetMinutes) * 60 : nil
        appState.startFocusSession(title: deskTitleText, targetDuration: target, projectName: deskProjectText)
        resetDeskEntry()
    }

    private func resetDeskEntry() {
        showDeskTitleEntry = false
        deskTitleText = ""
        deskProjectText = ""
        deskTargetMinutes = 0
    }
}

// MARK: - App Breakdown

private struct AppBreakdownSection: View {
    @EnvironmentObject private var appState: AppState
    var projectFilter: String? = nil

    private var totals: [AppUsageTotal] {
        guard let projectFilter, !projectFilter.isEmpty else {
            return appState.todayAppTotals
        }
        guard let record = appState.todayRecord else { return [] }

        var accumulated: [String: (appName: String, duration: TimeInterval)] = [:]
        for session in record.sessions where session.projectName == projectFilter {
            for entry in session.perAppDurations {
                if accumulated[entry.bundleIdentifier] != nil {
                    accumulated[entry.bundleIdentifier]!.duration += entry.duration
                } else {
                    accumulated[entry.bundleIdentifier] = (entry.appName, entry.duration)
                }
            }
        }

        return accumulated
            .map { AppUsageTotal(appName: $0.value.appName, bundleIdentifier: $0.key, totalDuration: $0.value.duration) }
            .sorted { $0.totalDuration > $1.totalDuration }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Breakdown")
                .font(.title3)
                .fontWeight(.semibold)

            if totals.isEmpty {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .overlay(
                        Text("No app data today")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    )
            } else {
                TodayAppDonutChart(totals: totals)
            }
        }
    }
}

// MARK: - Quick Insights

private struct QuickInsightsSection: View {
    @EnvironmentObject private var appState: AppState

    private static let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible())
    ]

    var body: some View {
        let top = appState.topAppToday
        let longest = appState.longestSessionToday
        let best = appState.mostActiveDayThisWeek

        if top != nil || longest != nil || best != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Insights")
                    .font(.title3)
                    .fontWeight(.semibold)

                LazyVGrid(columns: Self.columns, spacing: 10) {
                    if let top {
                        QuickInsightCard(
                            title: "Top App",
                            value: top.appName,
                            secondary: DurationTextFormatter.string(from: top.duration)
                        )
                    }
                    if let longest {
                        QuickInsightCard(
                            title: "Longest Session",
                            value: DurationTextFormatter.string(from: longest)
                        )
                    }
                    if let best {
                        QuickInsightCard(
                            title: "Best Day",
                            value: best.dayName,
                            secondary: DurationTextFormatter.string(from: best.duration)
                        )
                    }
                }
            }
        }
    }
}

private struct QuickInsightCard: View {
    let title: String
    let value: String
    var secondary: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let secondary {
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.08))
        )
    }
}

// MARK: - Today App Donut Chart

private struct TodayAppDonutChart: View {
    let totals: [AppUsageTotal]

    @State private var hoveredEntry: Entry? = nil
    @State private var tooltipLocation: CGPoint = .zero

    private static let palette: [Color] = [
        .blue, .indigo, .teal, .orange, .purple,
        Color.secondary.opacity(0.55)
    ]

    private static let chartSize: CGFloat = 140

    private struct Entry: Identifiable {
        let id: String
        let name: String
        let duration: TimeInterval
    }

    private var entries: [Entry] {
        let top = Array(totals.prefix(5))
        var result = top.map { Entry(id: $0.bundleIdentifier, name: $0.appName, duration: $0.totalDuration) }
        let remainder = totals.dropFirst(5).reduce(0.0) { $0 + $1.totalDuration }
        if remainder > 0 {
            result.append(Entry(id: "other", name: "Other", duration: remainder))
        }
        return result
    }

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            let size = Self.chartSize
            ZStack(alignment: .topLeading) {
                Chart(entries) { entry in
                    SectorMark(
                        angle: .value("Duration", entry.duration),
                        innerRadius: .ratio(0.52),
                        angularInset: 1.5
                    )
                    .cornerRadius(3)
                    .foregroundStyle(by: .value("App", entry.id))
                    .opacity(hoveredEntry == nil || hoveredEntry?.id == entry.id ? 1.0 : 0.35)
                }
                .chartForegroundStyleScale(
                    domain: entries.map(\.id),
                    range: Array(Self.palette.prefix(entries.count))
                )
                .chartLegend(.hidden)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    tooltipLocation = location
                                    let cx = geo.size.width / 2
                                    let cy = geo.size.height / 2
                                    let dx = location.x - cx
                                    let dy = location.y - cy
                                    let dist = sqrt(dx * dx + dy * dy)
                                    let outerR = min(geo.size.width, geo.size.height) / 2
                                    let innerR = outerR * 0.52
                                    guard dist >= innerR && dist <= outerR else {
                                        hoveredEntry = nil
                                        return
                                    }
                                    var angle = atan2(dx, -dy) * 180 / .pi
                                    if angle < 0 { angle += 360 }
                                    let total = entries.reduce(0.0) { $0 + $1.duration }
                                    var cumulative: Double = 0
                                    for entry in entries {
                                        cumulative += (entry.duration / total) * 360
                                        if angle <= cumulative {
                                            hoveredEntry = entry
                                            return
                                        }
                                    }
                                    hoveredEntry = nil
                                case .ended:
                                    hoveredEntry = nil
                                }
                            }
                    }
                }
                .frame(width: size, height: size)

                if let entry = hoveredEntry {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(DurationTextFormatter.string(from: entry.duration))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                    )
                    .position(x: tooltipLocation.x + 14, y: tooltipLocation.y - 22)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: size, height: size)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    let isHovered = hoveredEntry?.id == entry.id
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Self.palette[min(index, Self.palette.count - 1)])
                            .frame(width: 8, height: 8)
                        Text(entry.name)
                            .font(.caption)
                            .fontWeight(isHovered ? .medium : .regular)
                            .lineLimit(1)
                        Spacer()
                        Text(DurationTextFormatter.string(from: entry.duration))
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundStyle(isHovered ? .primary : .secondary)
                    }
                    .opacity(hoveredEntry == nil || isHovered ? 1.0 : 0.45)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.06)))
    }
}

// MARK: - Weekly Summary

private struct WeeklySummarySection: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isShowingWeeklyDetails: Bool
    @Binding var isShowingWeeklyReview: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly View")
                .font(.title3)
                .fontWeight(.semibold)

            let summaries = appState.weeklyDaySummaries
            WeeklyBarChart(summaries: summaries)

            HStack(spacing: 10) {
                Button {
                    isShowingWeeklyDetails = true
                } label: {
                    Text("Show Details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.10)))
                }
                .buttonStyle(.plain)

                Button {
                    isShowingWeeklyReview = true
                } label: {
                    Text("Weekly Review")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.10)))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// MARK: - Weekly Details View

private struct WeeklyDetailsView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isShowing: Bool
    let onRenameSession: (TrackedSession) -> Void
    let onLabelSession: (TrackedSession) -> Void
    var onProjectTap: ((String) -> Void)? = nil
    @State private var selectedDay: Date? = nil

    private var summaries: [DaySummary] { appState.weeklyDaySummaries }

    private var weeklyTotalDuration: TimeInterval {
        summaries.reduce(0) { $0 + $1.totalDuration }
    }

    private var weeklyTotalSessions: Int {
        summaries.reduce(0) { $0 + $1.sessionCount }
    }

    private func appTotals(for date: Date) -> [(bundleIdentifier: String, appName: String, duration: TimeInterval)] {
        guard let record = appState.recordedDays.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }) else { return [] }
        var totals: [String: (appName: String, duration: TimeInterval)] = [:]
        for session in record.sessions {
            for entry in session.perAppDurations {
                if totals[entry.bundleIdentifier] != nil {
                    totals[entry.bundleIdentifier]!.duration += entry.duration
                } else {
                    totals[entry.bundleIdentifier] = (entry.appName, entry.duration)
                }
            }
        }
        return totals
            .map { (bundleIdentifier: $0.key, appName: $0.value.appName, duration: $0.value.duration) }
            .sorted { $0.duration > $1.duration }
    }

    var body: some View {
        if let day = selectedDay,
           let summary = summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
            DayDetailsView(
                summary: summary,
                appTotals: appTotals(for: day),
                onBack: { selectedDay = nil },
                onRenameSession: onRenameSession,
                onLabelSession: onLabelSession,
                onProjectTap: onProjectTap
            )
        } else {
            weeklyContent
        }
    }

    private var weeklyContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button {
                    isShowing = false
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline)
                        Text("Back")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.secondary.opacity(0.10))
                    )
                }
                .buttonStyle(.plain)

                // Weekly totals header
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(DurationTextFormatter.string(from: weeklyTotalDuration))
                            .font(.title)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        Text("Total This Week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(weeklyTotalSessions)")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Text(weeklyTotalSessions == 1 ? "session" : "sessions")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.12))
                )

                WeeklyHeatmapGrid(summaries: summaries, onSelectDay: { selectedDay = $0 })

                VStack(alignment: .leading, spacing: 12) {
                    Text("Daily Breakdown")
                        .font(.title3)
                        .fontWeight(.semibold)

                    VStack(spacing: 6) {
                        ForEach(summaries.reversed()) { summary in
                            WeekDayRow(
                                summary: summary,
                                appTotals: appTotals(for: summary.date),
                                onSelect: summary.sessionCount > 0
                                    ? { selectedDay = summary.date }
                                    : nil
                            )
                        }
                    }
                }
            }
            .padding(32)
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}

// MARK: - Week Day Row

private struct WeekDayRow: View {
    let summary: DaySummary
    let appTotals: [(bundleIdentifier: String, appName: String, duration: TimeInterval)]
    var onSelect: (() -> Void)? = nil

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    var body: some View {
        Button {
            onSelect?()
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Self.dayFormatter.string(from: summary.date))
                        .font(.subheadline)
                        .foregroundStyle(summary.sessionCount == 0 ? .tertiary : .primary)
                    if summary.sessionCount > 0, let top = appTotals.first {
                        Text(top.appName)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if summary.sessionCount > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(DurationTextFormatter.string(from: summary.totalDuration))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .monospacedDigit()
                        Text("\(summary.sessionCount) \(summary.sessionCount == 1 ? "session" : "sessions")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if onSelect != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 4)
                    }
                } else {
                    Text("—")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
            .padding(12)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.secondary.opacity(summary.sessionCount == 0 ? 0.04 : 0.08))
        )
    }
}

// MARK: - Weekly Bar Chart

private struct WeeklyBarChart: View {
    let summaries: [DaySummary]
    @State private var hoveredDate: Date? = nil
    @State private var tooltipLocation: CGPoint = .zero

    private var hasAnyData: Bool {
        summaries.contains { $0.totalDuration > 0 }
    }

    private var hoveredSummary: DaySummary? {
        guard let hovered = hoveredDate else { return nil }
        return summaries.first {
            Calendar.current.isDate($0.date, inSameDayAs: hovered) && $0.totalDuration > 0
        }
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    var body: some View {
        if hasAnyData {
            ZStack(alignment: .topLeading) {
                Chart(summaries) { summary in
                    let isActive = hoveredDate.map {
                        Calendar.current.isDate(summary.date, inSameDayAs: $0)
                    } ?? false
                    BarMark(
                        x: .value("Day", summary.date, unit: .day),
                        y: .value("Hours", summary.totalDuration / 3600)
                    )
                    .foregroundStyle(
                        summary.totalDuration > 0
                            ? Color.accentColor.opacity(0.75)
                            : Color.secondary.opacity(0.12)
                    )
                    .cornerRadius(4)
                    .opacity(hoveredDate == nil || isActive ? 1.0 : 0.35)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.secondary.opacity(0.15))
                        AxisValueLabel {
                            if let h = value.as(Double.self), h > 0 {
                                Text("\(Int(h))h")
                                    .font(.caption2)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    tooltipLocation = location
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let origin = geo[plotFrame].origin
                                    let x = location.x - origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        hoveredDate = date
                                    }
                                case .ended:
                                    hoveredDate = nil
                                }
                            }
                    }
                }
                .frame(height: 140)

                if let summary = hoveredSummary {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.weekdayFormatter.string(from: summary.date))
                            .font(.caption2)
                            .fontWeight(.medium)
                        Text(DurationTextFormatter.string(from: summary.totalDuration))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                    )
                    .position(x: tooltipLocation.x + 12, y: tooltipLocation.y - 22)
                    .allowsHitTesting(false)
                }
            }
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.06))
                .frame(maxWidth: .infinity, minHeight: 100)
                .overlay(
                    Text("No data this week")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                )
        }
    }
}

// MARK: - Day Details View

private struct DayDetailsView: View {
    @EnvironmentObject private var appState: AppState

    let summary: DaySummary
    let appTotals: [(bundleIdentifier: String, appName: String, duration: TimeInterval)]
    let onBack: () -> Void
    let onRenameSession: (TrackedSession) -> Void
    let onLabelSession: (TrackedSession) -> Void
    var onProjectTap: ((String) -> Void)? = nil

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()


    private var sessions: [TrackedSession] {
        (appState.recordedDays
            .first(where: { Calendar.current.isDate($0.date, inSameDayAs: summary.date) })?
            .sessions) ?? []
    }

    private var longestSession: TimeInterval? {
        sessions.map(\.segmentDuration).max()
    }

    private var averageSession: TimeInterval? {
        guard summary.sessionCount > 0 else { return nil }
        return summary.totalDuration / Double(summary.sessionCount)
    }

    private var focusScore: Int? {
        guard let avg = averageSession, let longest = longestSession, longest > 0 else { return nil }
        return min(Int((avg / longest) * 100), 100)
    }

    private var productivityScore: Int? {
        guard let longest = longestSession, summary.totalDuration > 0 else { return nil }
        return min(Int((longest / summary.totalDuration) * 100), 100)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button(action: onBack) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline)
                        Text("Back")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.secondary.opacity(0.10))
                    )
                }
                .buttonStyle(.plain)

                // Day header
                Text(Self.dayFormatter.string(from: summary.date))
                    .font(.title2)
                    .fontWeight(.semibold)

                // Summary stats
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(DurationTextFormatter.string(from: summary.totalDuration))
                            .font(.title)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        Text("Total Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(summary.sessionCount)")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Text(summary.sessionCount == 1 ? "session" : "sessions")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.12))
                )

                // Insight cards (2×2)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    InsightCard(
                        title: "Longest Session",
                        value: longestSession.map { DurationTextFormatter.string(from: $0) } ?? "—"
                    )
                    InsightCard(
                        title: "Avg Session",
                        value: averageSession.map { DurationTextFormatter.string(from: $0) } ?? "—"
                    )
                    InsightCard(
                        title: "Focus Score",
                        value: focusScore.map { "\($0)%" } ?? "—",
                        note: "Experimental"
                    )
                    InsightCard(
                        title: "Productivity Score",
                        value: productivityScore.map { "\($0)%" } ?? "—",
                        note: "Experimental"
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("App Usage")
                        .font(.title3)
                        .fontWeight(.semibold)

                    if appTotals.isEmpty {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.secondary.opacity(0.06))
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .overlay(
                                Text("No app data for this day")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            )
                    } else {
                        DayDonutChart(appTotals: appTotals, totalDuration: summary.totalDuration)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Sessions")
                        .font(.title3)
                        .fontWeight(.semibold)

                    if sessions.isEmpty {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.secondary.opacity(0.06))
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .overlay(
                                Text("No sessions for this day")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(sessions.reversed(), id: \.id) { session in
                                HStack(alignment: .top, spacing: 12) {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 7, height: 7)
                                        .padding(.top, 14)
                                    SessionRow(session: session, onRename: onRenameSession, onLabel: onLabelSession, onProjectTap: onProjectTap)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            }
            .padding(32)
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}

// MARK: - Insight Card

private struct InsightCard: View {
    let title: String
    let value: String
    var note: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.3)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
                .lineLimit(1)
            if let note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.08))
        )
    }
}

// MARK: - Day Donut Chart

private struct DayDonutChart: View {
    let appTotals: [(bundleIdentifier: String, appName: String, duration: TimeInterval)]
    let totalDuration: TimeInterval

    @State private var hoveredEntry: Entry? = nil
    @State private var tooltipLocation: CGPoint = .zero

    // Interleaved warm/cool for maximum adjacent separation
    private static let palette: [Color] = [
        .blue.opacity(0.75),
        .orange.opacity(0.72),
        .purple.opacity(0.70),
        .teal.opacity(0.72),
        .pink.opacity(0.68),
        .indigo.opacity(0.70),
        .green.opacity(0.68),
        .yellow.opacity(0.65),
        .mint.opacity(0.68),
        Color.secondary.opacity(0.45)
    ]

    private static let chartSize: CGFloat = 180

    private struct Entry: Identifiable {
        let id: String
        let name: String
        let duration: TimeInterval
    }

    private var entries: [Entry] {
        appTotals.map { Entry(id: $0.bundleIdentifier, name: $0.appName, duration: $0.duration) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            let size = Self.chartSize
            ZStack(alignment: .topLeading) {
                Chart(entries) { entry in
                    SectorMark(
                        angle: .value("Duration", entry.duration),
                        innerRadius: .ratio(0.52),
                        angularInset: 1.5
                    )
                    .cornerRadius(3)
                    .foregroundStyle(by: .value("App", entry.id))
                    .opacity(hoveredEntry == nil || hoveredEntry?.id == entry.id ? 1.0 : 0.35)
                }
                .chartForegroundStyleScale(
                    domain: entries.map(\.id),
                    range: (0..<entries.count).map { Self.palette[$0 % Self.palette.count] }
                )
                .chartLegend(.hidden)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    tooltipLocation = location
                                    let cx = geo.size.width / 2
                                    let cy = geo.size.height / 2
                                    let dx = location.x - cx
                                    let dy = location.y - cy
                                    let dist = sqrt(dx * dx + dy * dy)
                                    let outerR = min(geo.size.width, geo.size.height) / 2
                                    let innerR = outerR * 0.52
                                    guard dist >= innerR && dist <= outerR else {
                                        hoveredEntry = nil
                                        return
                                    }
                                    var angle = atan2(dx, -dy) * 180 / .pi
                                    if angle < 0 { angle += 360 }
                                    let total = entries.reduce(0.0) { $0 + $1.duration }
                                    var cumulative: Double = 0
                                    for entry in entries {
                                        cumulative += (entry.duration / total) * 360
                                        if angle <= cumulative {
                                            hoveredEntry = entry
                                            return
                                        }
                                    }
                                    hoveredEntry = nil
                                case .ended:
                                    hoveredEntry = nil
                                }
                            }
                    }
                }
                .frame(width: size, height: size)

                // Center label
                VStack(spacing: 2) {
                    Text(DurationTextFormatter.string(from: totalDuration))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    Text("Day Total")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(width: size, height: size)
                .allowsHitTesting(false)

                // Hover tooltip
                if let entry = hoveredEntry {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(DurationTextFormatter.string(from: entry.duration))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                    )
                    .position(x: tooltipLocation.x + 14, y: tooltipLocation.y - 22)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: size, height: size)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    let isHovered = hoveredEntry?.id == entry.id
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Self.palette[index % Self.palette.count])
                            .frame(width: 8, height: 8)
                        Text(entry.name)
                            .font(.caption)
                            .fontWeight(isHovered ? .medium : .regular)
                            .lineLimit(1)
                        Spacer()
                        Text(DurationTextFormatter.string(from: entry.duration))
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundStyle(isHovered ? .primary : .secondary)
                    }
                    .opacity(hoveredEntry == nil || isHovered ? 1.0 : 0.45)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.06)))
    }
}

// MARK: - Weekly Heatmap Grid

private struct WeeklyHeatmapGrid: View {
    let summaries: [DaySummary]
    var onSelectDay: ((Date) -> Void)? = nil

    @State private var hoveredSummary: DaySummary? = nil

    private var maxDuration: TimeInterval {
        summaries.map(\.totalDuration).max() ?? 0
    }

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(summaries) { summary in
                    HeatmapTile(
                        summary: summary,
                        intensity: maxDuration > 0 ? summary.totalDuration / maxDuration : 0,
                        isHovered: hoveredSummary?.id == summary.id,
                        onHover: { active in hoveredSummary = active ? summary : nil },
                        onTap: onSelectDay.map { handler in { handler(summary.date) } }
                    )
                }
            }

            // Inline detail strip — fixed height to prevent layout shift
            Group {
                if let hovered = hoveredSummary {
                    HStack(spacing: 5) {
                        Text(Self.fullDateFormatter.string(from: hovered.date))
                            .fontWeight(.medium)
                        if hovered.totalDuration > 0 {
                            Text("·").foregroundStyle(.tertiary)
                            Text(DurationTextFormatter.string(from: hovered.totalDuration))
                                .monospacedDigit()
                            Text("·").foregroundStyle(.tertiary)
                            Text("\(hovered.sessionCount) \(hovered.sessionCount == 1 ? "session" : "sessions")")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("·").foregroundStyle(.tertiary)
                            Text("No activity").foregroundStyle(.tertiary)
                        }
                    }
                    .font(.caption)
                } else {
                    Color.clear
                }
            }
            .frame(height: 16)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.06)))
    }
}

private struct HeatmapTile: View {
    let summary: DaySummary
    let intensity: Double
    let isHovered: Bool
    let onHover: (Bool) -> Void
    var onTap: (() -> Void)? = nil

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private var fillOpacity: Double {
        guard summary.totalDuration > 0 else { return 0 }
        return 0.07 + pow(intensity, 0.7) * 0.75
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: 3) {
                Text(Self.dayFormatter.string(from: summary.date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 0)

                if summary.totalDuration > 0 {
                    Text(DurationTextFormatter.string(from: summary.totalDuration))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text("\(summary.sessionCount)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("—")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary.opacity(0.30))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        summary.totalDuration > 0
                            ? Color.accentColor.opacity(fillOpacity)
                            : Color.secondary.opacity(0.14)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isHovered
                                    ? (summary.totalDuration > 0
                                        ? Color.accentColor.opacity(0.55)
                                        : Color.secondary.opacity(0.22))
                                    : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .onContinuousHover { phase in
            switch phase {
            case .active: onHover(true)
            case .ended: onHover(false)
            }
        }
    }
}

// MARK: - Settings View

private struct SettingsView: View {
    @EnvironmentObject private var updaterService: UpdaterService
    @StateObject private var launchAtLogin = LaunchAtLoginService()
    @AppStorage("com.veira.idleReminderMinutes") private var idleReminderMinutes: Int = 10
    @AppStorage("com.veira.pauseReminderMinutes") private var pauseReminderMinutes: Int = 5

    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: onBack) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.subheadline)
                            Text("Back")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.secondary.opacity(0.10))
                        )
                    }
                    .buttonStyle(.plain)

                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top, 4)
                    Text("Manage preferences, updates, and privacy.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Preferences
                SettingsSection(title: "Preferences") {
                    HStack {
                        Text("Launch at Login")
                            .font(.subheadline)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { launchAtLogin.isEnabled },
                            set: { _ in launchAtLogin.toggle() }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.08)))
                }

                // Notifications
                SettingsSection(title: "Notifications") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Idle pause after")
                                .font(.subheadline)
                            Spacer()
                            Picker("", selection: $idleReminderMinutes) {
                                ForEach([1, 3, 5, 10], id: \.self) { minutes in
                                    Text(minutes == 1 ? "1 minute" : "\(minutes) minutes").tag(minutes)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.08)))

                        HStack {
                            Text("Paused reminder after")
                                .font(.subheadline)
                            Spacer()
                            Picker("", selection: $pauseReminderMinutes) {
                                ForEach([1, 3, 5, 10], id: \.self) { minutes in
                                    Text(minutes == 1 ? "1 minute" : "\(minutes) minutes").tag(minutes)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.08)))
                    }
                }

                // Updates
                SettingsSection(title: "Updates") {
                    Button {
                        updaterService.checkForUpdates()
                    } label: {
                        Group {
                            if updaterService.isUpdateAvailable {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Update Available")
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        if let version = updaterService.latestVersion {
                                            Text("Version \(version)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text("Update Now")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.accentColor)
                                }
                            } else {
                                HStack {
                                    Text("Check for Updates…")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.08)))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(!updaterService.canCheckForUpdates)
                    .opacity(updaterService.canCheckForUpdates ? 1.0 : 0.45)
                }

                // About
                SettingsSection(title: "About") {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Veira")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                                Text("Version \(version) (\(build))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.08)))
                }

                // Privacy
                SettingsSection(title: "Privacy") {
                    Text("All activity data is stored locally on your Mac. No screenshots, keystrokes, or clipboard content are ever captured. Update checks contact GitHub only for release metadata and downloads.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.06)))
                }
            }
            .padding(32)
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.5)
            content
        }
    }
}

// MARK: - Session Completion Summary

private struct SessionCompletionView: View {
    let session: TrackedSession
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 6) {
                    Text("Session Complete")
                        .font(.title2)
                        .fontWeight(.semibold)
                    if session.isFocusSession {
                        Text(session.displayTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let project = session.projectName, !project.isEmpty {
                        Text(project)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.secondary.opacity(0.12)))
                    }
                }

                // Elapsed duration
                VStack(spacing: 4) {
                    Text(DurationTextFormatter.clock(from: session.segmentDuration))
                        .font(.system(size: 56, weight: .ultraLight, design: .monospaced))
                        .monospacedDigit()
                    Text("Total time")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Desk: target reached/missed
                if session.isFocusSession, let target = session.targetDuration, target > 0 {
                    let reached = session.segmentDuration >= target
                    HStack(spacing: 8) {
                        Image(systemName: reached ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(reached ? Color.green : Color.secondary)
                        Text(reached
                             ? "Goal of \(DurationTextFormatter.clock(from: target)) reached"
                             : "Goal of \(DurationTextFormatter.clock(from: target)) — \(DurationTextFormatter.clock(from: max(0, target - session.segmentDuration))) short")
                            .font(.subheadline)
                            .foregroundStyle(reached ? Color.primary : Color.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(reached ? Color.green.opacity(0.10) : Color.secondary.opacity(0.10))
                    )
                }

                // Computer: top apps
                if !session.isFocusSession {
                    let topApps = Array(session.perAppDurations.prefix(3))
                    if !topApps.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Top Apps")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(topApps, id: \.bundleIdentifier) { entry in
                                HStack {
                                    Text(entry.appName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(DurationTextFormatter.string(from: entry.duration))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.08)))
                        .frame(maxWidth: 320)
                    }
                }

                Button("Done", action: onDismiss)
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
            }
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Desk Session Timer View

private struct DeskTimerView: View {
    @EnvironmentObject private var appState: AppState
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline)
                        Text("Back")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.secondary.opacity(0.10))
                    )
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)

            Spacer()

            VStack(spacing: 16) {
                Text(appState.sessionState == .active ? "Desk Session" : "Paused")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.secondary.opacity(0.12)))

                Text(appState.activeFocusTitle ?? "Desk Session")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                if let project = appState.activeSessionProjectName, !project.isEmpty {
                    Text(project)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.secondary.opacity(0.12)))
                }

                Text(DurationTextFormatter.clock(from: appState.currentTotalSessionDuration))
                    .font(.system(size: 72, weight: .ultraLight, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                // Target progress — shown only when a target was set for this session.
                if let target = appState.activeFocusTargetDuration, target > 0 {
                    let elapsed = appState.currentTotalSessionDuration
                    let progress = min(1.0, elapsed / target)
                    let reached = elapsed >= target
                    VStack(spacing: 5) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.secondary.opacity(0.15))
                                    .frame(height: 6)
                                if progress > 0 {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(reached ? Color.green.opacity(0.8) : Color.accentColor.opacity(0.75))
                                        .frame(width: geo.size.width * CGFloat(progress), height: 6)
                                }
                            }
                        }
                        .frame(height: 6)
                        HStack {
                            Text(reached ? "Goal reached" : "Goal: \(DurationTextFormatter.clock(from: target))")
                                .font(.caption2)
                                .foregroundStyle(reached ? Color.green : Color.secondary)
                            Spacer()
                            if !reached {
                                Text("\(DurationTextFormatter.clock(from: max(0, target - elapsed))) remaining")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .frame(maxWidth: 320)
                }

                HStack(spacing: 12) {
                    Button {
                        if appState.sessionState == .active {
                            appState.pauseSession()
                        } else {
                            appState.resumeSession()
                        }
                    } label: {
                        Text(appState.sessionState == .active ? "Pause" : "Resume")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(width: 110)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.secondary.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)

                    Button { appState.endSession() } label: {
                        Text("End Session")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(width: 110)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.secondary.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}

// MARK: - Desk Session Banner

// Compact banner shown in the normal dashboard when a desk session is active but
// the user has navigated away from the timer view. Tapping it returns to the timer.
private struct DeskSessionBanner: View {
    @EnvironmentObject private var appState: AppState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(appState.sessionState.indicatorColor)
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(appState.activeFocusTitle ?? "Desk Session")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let project = appState.activeSessionProjectName, !project.isEmpty {
                            Text(project)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.secondary.opacity(0.12)))
                                .lineLimit(1)
                        }
                    }
                    Text(DurationTextFormatter.clock(from: appState.currentTotalSessionDuration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("Open Timer")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Project Label Dialog

private struct ProjectLabelDialog: View {
    let session: TrackedSession
    @Binding var labelText: String
    let onCancel: () -> Void
    let onDone: () -> Void
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.32).ignoresSafeArea().onTapGesture(perform: onCancel)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text((session.projectName ?? "").isEmpty ? "Assign Project" : "Edit Project")
                        .font(.headline).fontWeight(.semibold)
                    Text("Optional label shown on the session row.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                TextField("e.g. Q3 Planning", text: $labelText)
                    .textFieldStyle(.plain)
                    .font(.title3).fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.10)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.18), lineWidth: 1))
                    .focused($isFieldFocused)
                    .onSubmit(onDone)
                HStack(spacing: 8) {
                    if !(session.projectName ?? "").isEmpty {
                        Button("Clear") { labelText = ""; onDone() }
                            .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.10)))
                    }
                    Spacer()
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.plain).font(.caption).fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.10)))
                    Button("Done", action: onDone)
                        .buttonStyle(.plain).font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor))
                }
            }
            .padding(20).frame(width: 360)
            .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial)
                .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 14))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { isFieldFocused = true }
    }
}

// MARK: - Weekly Review View

private struct WeeklyReviewView: View {
    @EnvironmentObject private var appState: AppState
    let onBack: () -> Void
    var onProjectTap: ((String) -> Void)? = nil

    private var calendar: Calendar { .current }

    // Last 7 calendar days ending today
    private var reviewDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    private var allSessions: [TrackedSession] {
        reviewDays.flatMap { day in
            appState.recordedDays.first(where: { calendar.isDate($0.date, inSameDayAs: day) })?.sessions ?? []
        }
    }

    private var totalDuration: TimeInterval { allSessions.reduce(0) { $0 + $1.segmentDuration } }
    private var deskDuration: TimeInterval { allSessions.filter(\.isFocusSession).reduce(0) { $0 + $1.segmentDuration } }
    private var computerDuration: TimeInterval { allSessions.filter { !$0.isFocusSession }.reduce(0) { $0 + $1.segmentDuration } }
    private var sessionCount: Int { Set(allSessions.map(\.id)).count }

    private var projectTotals: [(name: String, duration: TimeInterval)] {
        var totals: [String: TimeInterval] = [:]
        for s in allSessions {
            guard let p = s.projectName, !p.isEmpty else { continue }
            totals[p, default: 0] += s.segmentDuration
        }
        return totals.map { ($0.key, $0.value) }.sorted { $0.duration > $1.duration }
    }

    private var topComputerApps: [(bundleIdentifier: String, appName: String, duration: TimeInterval)] {
        var totals: [String: (appName: String, duration: TimeInterval)] = [:]
        for s in allSessions where !s.isFocusSession {
            for entry in s.perAppDurations {
                if totals[entry.bundleIdentifier] != nil {
                    totals[entry.bundleIdentifier]!.duration += entry.duration
                } else {
                    totals[entry.bundleIdentifier] = (entry.appName, entry.duration)
                }
            }
        }
        return totals
            .map { (bundleIdentifier: $0.key, appName: $0.value.appName, duration: $0.value.duration) }
            .sorted { $0.duration > $1.duration }
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE MMM d"; return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Button(action: onBack) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left").font(.subheadline)
                        Text("Back").font(.subheadline).fontWeight(.medium)
                    }
                    .foregroundStyle(.primary).padding(.horizontal, 12).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.10)))
                }
                .buttonStyle(.plain)

                Text("Weekly Review").font(.title2).fontWeight(.semibold)

                // Totals
                reviewSection("This Week") {
                    ReviewRow(label: "Total Tracked", value: DurationTextFormatter.string(from: totalDuration), isTotal: true)
                    ReviewRow(label: "Computer Sessions", value: DurationTextFormatter.string(from: computerDuration))
                    ReviewRow(label: "Desk Sessions", value: DurationTextFormatter.string(from: deskDuration))
                    ReviewRow(label: "Sessions", value: "\(sessionCount)")
                }

                // Projects — tappable when onProjectTap is set
                if !projectTotals.isEmpty {
                    reviewSection("Projects") {
                        ForEach(projectTotals, id: \.name) { p in
                            if let handler = onProjectTap {
                                Button { handler(p.name) } label: {
                                    ReviewRow(label: p.name, value: DurationTextFormatter.string(from: p.duration), isClickable: true)
                                }
                                .buttonStyle(.plain)
                            } else {
                                ReviewRow(label: p.name, value: DurationTextFormatter.string(from: p.duration))
                            }
                        }
                    }
                }

                // Top computer apps
                if !topComputerApps.isEmpty {
                    reviewSection("Top Apps") {
                        ForEach(topComputerApps.prefix(5), id: \.bundleIdentifier) { app in
                            ReviewRow(label: app.appName, value: DurationTextFormatter.string(from: app.duration))
                        }
                    }
                }

                // Day by day
                reviewSection("Daily Breakdown") {
                    ForEach(reviewDays, id: \.self) { day in
                        let daySessions = appState.recordedDays.first(where: { calendar.isDate($0.date, inSameDayAs: day) })?.sessions ?? []
                        let dur = daySessions.reduce(0.0) { $0 + $1.segmentDuration }
                        ReviewRow(
                            label: Self.weekdayFormatter.string(from: day),
                            value: dur > 0 ? DurationTextFormatter.string(from: dur) : "—",
                            secondary: dur > 0 ? "\(daySessions.count) session\(daySessions.count == 1 ? "" : "s")" : nil
                        )
                    }
                }
            }
            .padding(32)
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    @ViewBuilder
    private func reviewSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption2).foregroundStyle(.tertiary).textCase(.uppercase).kerning(0.5)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.08)))
        }
    }
}

private struct ReviewRow: View {
    let label: String
    let value: String
    var secondary: String? = nil
    var isTotal: Bool = false
    var isClickable: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(isTotal ? .semibold : .regular)
                .foregroundStyle(isTotal ? .primary : .secondary)
            if let secondary {
                Text(secondary).font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(isTotal ? .semibold : .medium)
                .foregroundStyle(isTotal ? .primary : .secondary)
                .monospacedDigit()
            if isClickable {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

// MARK: - Project Detail View

private struct ProjectDetailView: View {
    @EnvironmentObject private var appState: AppState
    let projectName: String
    let onBack: () -> Void
    let onFilterToday: (() -> Void)?

    private var calendar: Calendar { .current }

    // Every slice across all recorded days that carries this project label.
    private var allSlices: [TrackedSession] {
        appState.recordedDays.flatMap(\.sessions).filter { $0.projectName == projectName }
    }

    // Unique session count (cross-midnight sessions produce multiple slices with the same id).
    private var uniqueSessionCount: Int { Set(allSlices.map(\.id)).count }

    private var totalDuration: TimeInterval  { allSlices.reduce(0) { $0 + $1.segmentDuration } }
    private var deskDuration: TimeInterval   { allSlices.filter(\.isFocusSession).reduce(0) { $0 + $1.segmentDuration } }
    private var computerDuration: TimeInterval { allSlices.filter { !$0.isFocusSession }.reduce(0) { $0 + $1.segmentDuration } }

    // Last 7 calendar days, newest first.
    private var reviewDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    private func dayDuration(for day: Date) -> TimeInterval {
        appState.recordedDays
            .first(where: { calendar.isDate($0.date, inSameDayAs: day) })?
            .sessions
            .filter { $0.projectName == projectName }
            .reduce(0) { $0 + $1.segmentDuration } ?? 0
    }

    // Most recent sessions for this project (last 14 days, up to 15, deduped by id).
    // Cross-midnight slices are merged so the row shows the full project session duration.
    private var recentSessions: [TrackedSession] {
        guard let cutoff = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: Date())) else {
            return []
        }
        let grouped = Dictionary(grouping: allSlices.filter { $0.endedAt >= cutoff }, by: \.id)
        return grouped.values
            .compactMap(mergedSession)
            .sorted { $0.endedAt > $1.endedAt }
            .prefix(15)
            .map { $0 }
    }

    private func mergedSession(from slices: [TrackedSession]) -> TrackedSession? {
        let sorted = slices.sorted { $0.startedAt < $1.startedAt }
        guard let first = sorted.first else { return nil }
        let latest = sorted.max { $0.endedAt < $1.endedAt } ?? first
        return TrackedSession(
            id: first.id,
            startedAt: sorted.map(\.startedAt).min() ?? first.startedAt,
            endedAt: sorted.map(\.endedAt).max() ?? first.endedAt,
            segments: sorted.flatMap(\.segments).sorted { $0.startTime < $1.startTime },
            title: latest.title ?? first.title,
            mode: latest.mode ?? first.mode,
            targetDuration: latest.targetDuration ?? first.targetDuration,
            projectName: projectName
        )
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE MMM d"; return f
    }()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left").font(.subheadline)
                            Text("Back").font(.subheadline).fontWeight(.medium)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.10)))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if let onFilterToday {
                        Button(action: onFilterToday) {
                            Text("Filter Today")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.10)))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(projectName).font(.title2).fontWeight(.semibold)

                // Overview stats
                detailSection("Overview") {
                    ReviewRow(label: "Total Time",  value: DurationTextFormatter.string(from: totalDuration), isTotal: true)
                    if deskDuration > 0     { ReviewRow(label: "Desk",     value: DurationTextFormatter.string(from: deskDuration)) }
                    if computerDuration > 0 { ReviewRow(label: "Computer", value: DurationTextFormatter.string(from: computerDuration)) }
                    ReviewRow(label: "Sessions", value: "\(uniqueSessionCount)")
                }

                // Recent sessions
                if !recentSessions.isEmpty {
                    detailSection("Recent Sessions") {
                        ForEach(recentSessions, id: \.id) { s in
                            ProjectSessionRow(session: s, timeFormatter: Self.timeFormatter)
                        }
                    }
                }

                // Day-by-day (last 7 days)
                detailSection("Last 7 Days") {
                    ForEach(reviewDays, id: \.self) { day in
                        let dur = dayDuration(for: day)
                        ReviewRow(
                            label: Self.weekdayFormatter.string(from: day),
                            value: dur > 0 ? DurationTextFormatter.string(from: dur) : "—"
                        )
                    }
                }
            }
            .padding(32)
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    @ViewBuilder
    private func detailSection<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption2).foregroundStyle(.tertiary).textCase(.uppercase).kerning(0.5)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.08)))
        }
    }
}

// Compact session row used inside ProjectDetailView (no action buttons needed).
private struct ProjectSessionRow: View {
    let session: TrackedSession
    let timeFormatter: DateFormatter

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.isFocusSession ? session.displayTitle : (session.appSummary.isEmpty ? "Computer Session" : session.appSummary))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("\(timeFormatter.string(from: session.startedAt)) – \(timeFormatter.string(from: session.endedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(DurationTextFormatter.string(from: session.segmentDuration))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

// MARK: - Helpers

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
