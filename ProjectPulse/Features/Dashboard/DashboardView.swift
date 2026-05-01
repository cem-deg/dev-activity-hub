import Charts
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var updaterService: UpdaterService
    @State private var isShowingWeeklyDetails = false
    @State private var isShowingSettings = false

    var body: some View {
        if isShowingSettings {
            SettingsView(onBack: { isShowingSettings = false })
        } else if isShowingWeeklyDetails {
            WeeklyDetailsView(isShowing: $isShowingWeeklyDetails)
                .environmentObject(appState)
        } else {
            mainDashboard
        }
    }

    private var mainDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
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
                VStack(alignment: .leading, spacing: 8) {
                    let streak = appState.currentStreakDays
                    Text(streak > 0 ? "\(streak) Day Streak 🔥" : "Start your streak today")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(streak > 0 ? .primary : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.secondary.opacity(0.10)))
                    SessionStatusCard()
                }
                TodaySummarySection()
                AppBreakdownSection()
                WeeklySummarySection(isShowingWeeklyDetails: $isShowingWeeklyDetails)
            }
            .padding(32)
        }
        .frame(minWidth: 640, minHeight: 480)
    }

}

// MARK: - Today Summary

private struct TodaySummarySection: View {
    @EnvironmentObject private var appState: AppState
    @State private var showAllSessions = false

    private static let defaultSessionLimit = 2

    private var sessions: [TrackedSession] {
        (appState.todayRecord?.sessions ?? []).reversed()
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
        .padding(16)
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
                SessionRow(session: session)
            }
            if needsToggle {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showAllSessions.toggle()
                    }
                } label: {
                    Text(showAllSessions ? "Show less" : "Show all sessions")
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
    @State private var isExpanded = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    var body: some View {
        let start = Self.timeFormatter.string(from: session.startedAt)
        let end = Self.timeFormatter.string(from: session.endedAt)
        let duration = session.segmentDuration
        let apps = session.appSummary
        let breakdown = session.perAppDurations

        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(DurationTextFormatter.string(from: duration))
                            .font(.subheadline)
                            .fontWeight(.medium)
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
                                    .foregroundStyle(.secondary)
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
                .contentShape(Rectangle())
                .padding(12)
            }
            .buttonStyle(.plain)

            if isExpanded && !breakdown.isEmpty {
                Divider()
                    .padding(.horizontal, 12)
                    .opacity(0.6)
                VStack(spacing: 6) {
                    ForEach(breakdown, id: \.appName) { entry in
                        HStack {
                            Text(entry.appName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(DurationTextFormatter.string(from: entry.duration))
                                .font(.caption)
                                .fontWeight(.medium)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.secondary.opacity(0.08))
        )
    }
}

// MARK: - Session Status Card

private struct SessionStatusCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Status")
                .font(.title3)
                .fontWeight(.semibold)

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
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.12))
            )
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
            Button { appState.startSession() } label: {
                Text("Start")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor))
            }
            .buttonStyle(.plain)
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
}

// MARK: - App Breakdown

private struct AppBreakdownSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Breakdown")
                .font(.title3)
                .fontWeight(.semibold)

            let totals = appState.todayAppTotals

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
                    .foregroundStyle(by: .value("App", entry.name))
                    .opacity(hoveredEntry == nil || hoveredEntry?.id == entry.id ? 1.0 : 0.35)
                }
                .chartForegroundStyleScale(
                    domain: entries.map(\.name),
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly View")
                .font(.title3)
                .fontWeight(.semibold)

            let summaries = appState.weeklyDaySummaries
            WeeklyBarChart(summaries: summaries)

            Button {
                isShowingWeeklyDetails = true
            } label: {
                Text("Show Details")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.secondary.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// MARK: - Weekly Details View

private struct WeeklyDetailsView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isShowing: Bool
    @State private var selectedDay: Date? = nil

    private var summaries: [DaySummary] { appState.weeklyDaySummaries }

    private var weeklyTotalDuration: TimeInterval {
        summaries.reduce(0) { $0 + $1.totalDuration }
    }

    private var weeklyTotalSessions: Int {
        summaries.reduce(0) { $0 + $1.sessionCount }
    }

    private func appTotals(for date: Date) -> [(appName: String, duration: TimeInterval)] {
        guard let record = appState.recordedDays.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }) else { return [] }
        var totals: [String: TimeInterval] = [:]
        for session in record.sessions {
            for entry in session.perAppDurations {
                totals[entry.appName, default: 0] += entry.duration
            }
        }
        return totals.map { ($0.key, $0.value) }.sorted { $0.duration > $1.duration }
    }

    var body: some View {
        if let day = selectedDay,
           let summary = summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
            DayDetailsView(
                summary: summary,
                appTotals: appTotals(for: day),
                onBack: { selectedDay = nil }
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
    let appTotals: [(appName: String, duration: TimeInterval)]
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
                                    let origin = geo[proxy.plotAreaFrame].origin
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
    let appTotals: [(appName: String, duration: TimeInterval)]
    let onBack: () -> Void

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
                        VStack(spacing: 6) {
                            ForEach(sessions.reversed(), id: \.id) { session in
                                SessionRow(session: session)
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
    let appTotals: [(appName: String, duration: TimeInterval)]
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
        appTotals.map { Entry(id: $0.appName, name: $0.appName, duration: $0.duration) }
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
                    .foregroundStyle(by: .value("App", entry.name))
                    .opacity(hoveredEntry == nil || hoveredEntry?.id == entry.id ? 1.0 : 0.35)
                }
                .chartForegroundStyleScale(
                    domain: entries.map(\.name),
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
        return 0.10 + intensity * 0.55
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
                        .fontWeight(.medium)
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
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        summary.totalDuration > 0
                            ? Color.accentColor.opacity(fillOpacity)
                            : Color.secondary.opacity(0.07)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isHovered && summary.totalDuration > 0
                                    ? Color.accentColor.opacity(0.50)
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
                    Text("All activity data is stored locally on your Mac. No screenshots, keystrokes, or clipboard content are ever captured. Nothing is sent to any server.")
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
