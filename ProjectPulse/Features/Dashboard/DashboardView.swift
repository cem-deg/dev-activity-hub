import Charts
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingWeeklyDetails = false

    var body: some View {
        if isShowingWeeklyDetails {
            WeeklyDetailsView(isShowing: $isShowingWeeklyDetails)
                .environmentObject(appState)
        } else {
            mainDashboard
        }
    }

    private var mainDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SessionStatusCard()
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
                Text(appState.sessionState.statusLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.12))
            )
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

                WeeklyStackedBarChart(summaries: summaries, recordedDays: appState.recordedDays)

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

// MARK: - Weekly Stacked Bar Chart

private struct WeeklyStackedBarChart: View {
    let summaries: [DaySummary]
    let recordedDays: [WorkDayRecord]

    @State private var hoveredDate: Date? = nil
    @State private var tooltipLocation: CGPoint = .zero

    private static let topAppLimit = 5
    private static let palette: [Color] = [
        .blue.opacity(0.65),
        .teal.opacity(0.65),
        .indigo.opacity(0.60),
        .mint.opacity(0.65),
        .cyan.opacity(0.60),
        Color.secondary.opacity(0.32)
    ]

    private struct StackEntry: Identifiable {
        let id: String
        let date: Date
        let appName: String
        let duration: TimeInterval
    }

    private var topApps: [String] {
        var totals: [String: TimeInterval] = [:]
        let cal = Calendar.current
        for record in recordedDays where summaries.contains(where: { cal.isDate($0.date, inSameDayAs: record.date) }) {
            for session in record.sessions {
                for entry in session.perAppDurations {
                    totals[entry.appName, default: 0] += entry.duration
                }
            }
        }
        return totals.sorted { $0.value > $1.value }
            .prefix(Self.topAppLimit)
            .map(\.key)
    }

    private var entries: [StackEntry] {
        let top = Set(topApps)
        let cal = Calendar.current
        var result: [StackEntry] = []

        for summary in summaries where summary.totalDuration > 0 {
            guard let record = recordedDays.first(where: { cal.isDate($0.date, inSameDayAs: summary.date) }) else { continue }

            var dayTotals: [String: TimeInterval] = [:]
            for session in record.sessions {
                for entry in session.perAppDurations {
                    dayTotals[entry.appName, default: 0] += entry.duration
                }
            }

            var otherDuration: TimeInterval = 0
            for (appName, duration) in dayTotals {
                if top.contains(appName) {
                    result.append(StackEntry(
                        id: "\(summary.date.timeIntervalSince1970)-\(appName)",
                        date: summary.date,
                        appName: appName,
                        duration: duration
                    ))
                } else {
                    otherDuration += duration
                }
            }
            if otherDuration > 0 {
                result.append(StackEntry(
                    id: "\(summary.date.timeIntervalSince1970)-other",
                    date: summary.date,
                    appName: "Other",
                    duration: otherDuration
                ))
            }
        }
        return result
    }

    private var stackDomain: [String] {
        let present = Set(entries.map(\.appName))
        var domain = topApps.filter { present.contains($0) }
        if present.contains("Other") { domain.append("Other") }
        return domain
    }

    private var hasAnyData: Bool {
        summaries.contains { $0.totalDuration > 0 }
    }

    private var hoveredSummary: DaySummary? {
        guard let hovered = hoveredDate else { return nil }
        return summaries.first {
            Calendar.current.isDate($0.date, inSameDayAs: hovered) && $0.totalDuration > 0
        }
    }

    var body: some View {
        if hasAnyData {
            ZStack(alignment: .topLeading) {
                let domain = stackDomain
                Chart(entries) { entry in
                    BarMark(
                        x: .value("Day", entry.date, unit: .day),
                        y: .value("Hours", entry.duration / 3600)
                    )
                    .foregroundStyle(by: .value("App", entry.appName))
                }
                .chartForegroundStyleScale(
                    domain: domain,
                    range: Array(Self.palette.prefix(domain.count))
                )
                .chartLegend(.hidden)
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
                .frame(height: 160)

                if let summary = hoveredSummary {
                    Text(DurationTextFormatter.string(from: summary.totalDuration))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(.regularMaterial)
                                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                        )
                        .position(x: tooltipLocation.x + 12, y: tooltipLocation.y - 16)
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
