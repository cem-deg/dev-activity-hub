import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SessionStatusCard()
                TodaySummarySection()
                AppBreakdownSection()
                WeeklySummarySection()
            }
            .padding(32)
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}

// MARK: - Today Summary

private struct TodaySummarySection: View {
    @EnvironmentObject private var appState: AppState

    private var sessions: [TrackedSession] {
        appState.todayRecord?.sessions ?? []
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
        HStack(spacing: 32) {
            StatCell(label: "Sessions", value: "\(sessions.count)")
            StatCell(label: "Total Time", value: DurationTextFormatter.string(from: appState.todayTotalDuration))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.12))
        )
    }

    private var sessionList: some View {
        VStack(spacing: 6) {
            ForEach(sessions, id: \.id) { session in
                SessionRow(session: session)
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(start) – \(end)")
                            .font(.subheadline)
                        HStack(spacing: 8) {
                            Text(DurationTextFormatter.string(from: duration))
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
                VStack(spacing: 4) {
                    ForEach(breakdown, id: \.appName) { entry in
                        HStack {
                            Text(entry.appName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(DurationTextFormatter.string(from: entry.duration))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.secondary.opacity(0.08))
        )
    }
}

// MARK: - Stat Cell

private struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
                VStack(spacing: 6) {
                    ForEach(totals) { total in
                        AppTotalRow(total: total)
                    }
                }
            }
        }
    }
}

private struct AppTotalRow: View {
    let total: AppUsageTotal

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(total.appName)
                    .font(.subheadline)
                Text(total.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(DurationTextFormatter.string(from: total.totalDuration))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.secondary.opacity(0.08))
        )
    }
}

// MARK: - Weekly Summary

private struct WeeklySummarySection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly View")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 6) {
                ForEach(appState.weeklyDaySummaries) { summary in
                    WeekDayRow(summary: summary)
                }
            }
        }
    }
}

private struct WeekDayRow: View {
    let summary: DaySummary

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    var body: some View {
        HStack {
            Text(Self.dayFormatter.string(from: summary.date))
                .font(.subheadline)
                .foregroundStyle(summary.sessionCount == 0 ? .tertiary : .primary)
            Spacer()
            if summary.sessionCount > 0 {
                Text("\(summary.sessionCount) \(summary.sessionCount == 1 ? "session" : "sessions")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(DurationTextFormatter.string(from: summary.totalDuration))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 70, alignment: .trailing)
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.secondary.opacity(summary.sessionCount == 0 ? 0.04 : 0.08))
        )
    }
}

// MARK: - Helpers

private extension SessionState {
    var indicatorColor: Color {
        switch self {
        case .idle:   return Color.secondary
        case .active: return Color.green
        case .paused: return Color.orange
        }
    }
}
