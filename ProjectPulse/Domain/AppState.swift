import Foundation

enum SessionState {
    case idle
    case active
    case paused

    var statusLabel: String {
        switch self {
        case .idle:   return "No Active Session"
        case .active: return "Session Active"
        case .paused: return "Session Paused"
        }
    }
}

final class AppState: ObservableObject {
    @Published private(set) var sessionState: SessionState = .idle
    @Published var hasCompletedOnboarding: Bool = false

    private let monitor = ActiveAppMonitor()
    private let buffer = ActivityEventBuffer()
    private let segmentBuilder = ActivitySegmentBuilder()
    private let idleMonitor = IdleMonitor(threshold: 60)

    // Finalization boundary — unchanged across pause/resume cycles
    private var sessionStartedAt: Date?

    // Runtime display state — separate from finalization
    private var activeRunStartedAt: Date?
    private var accumulatedSessionDuration: TimeInterval = 0

    @Published private(set) var liveClockTick: Date = Date()
    private var displayTimer: Timer?

    @Published private var workDays: [WorkDayRecord] = []

    init() {
        monitor.onEvent = { [weak self] event in
            self?.buffer.append(event)
            self?.segmentBuilder.handle(event)
        }
        idleMonitor.onIdleStarted = { [weak self] lastActivityAt in self?.idlePause(lastActivityAt: lastActivityAt) }
        idleMonitor.onIdleEnded   = { [weak self] in self?.idleResume() }
    }

    // MARK: - Read-only surfaces

    var completedSegments: [ActivitySegment] {
        segmentBuilder.closedSegments
    }

    var recordedDays: [WorkDayRecord] {
        workDays
    }

    var todayRecord: WorkDayRecord? {
        let today = Calendar.current.startOfDay(for: Date())
        return workDays.first(where: { $0.date == today })
    }

    var sessionActiveRunStartedAt: Date? {
        activeRunStartedAt
    }

    var sessionAccumulatedDuration: TimeInterval {
        accumulatedSessionDuration
    }

    var todayTotalDuration: TimeInterval {
        guard let record = todayRecord else { return 0 }
        return record.sessions.flatMap(\.segments).compactMap(\.duration).reduce(0, +)
    }

    var weeklyDaySummaries: [DaySummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let sessions = workDays.first(where: { $0.date == day })?.sessions ?? []
            let duration = sessions.reduce(0.0) { $0 + $1.segmentDuration }
            return DaySummary(date: day, sessionCount: sessions.count, totalDuration: duration)
        }
    }

    var todayAppTotals: [AppUsageTotal] {
        guard let record = todayRecord else { return [] }

        var accumulated: [String: (appName: String, duration: TimeInterval)] = [:]

        for session in record.sessions {
            for segment in session.segments {
                guard let duration = segment.duration else { continue }
                if accumulated[segment.bundleIdentifier] != nil {
                    accumulated[segment.bundleIdentifier]!.duration += duration
                } else {
                    accumulated[segment.bundleIdentifier] = (segment.appName, duration)
                }
            }
        }

        return accumulated
            .map { AppUsageTotal(appName: $0.value.appName, bundleIdentifier: $0.key, totalDuration: $0.value.duration) }
            .sorted { $0.totalDuration > $1.totalDuration }
    }

    // MARK: - Session control

    func startSession() {
        guard sessionState == .idle else { return }
        let now = Date()
        sessionStartedAt = now
        activeRunStartedAt = now
        accumulatedSessionDuration = 0
        sessionState = .active
        monitor.start()
        startDisplayTimer()
        idleMonitor.start()
    }

    func pauseSession() {
        guard sessionState == .active else { return }
        let now = Date()
        if let runStart = activeRunStartedAt {
            accumulatedSessionDuration += now.timeIntervalSince(runStart)
        }
        activeRunStartedAt = nil
        sessionState = .paused
        monitor.stop()
        segmentBuilder.closeCurrentSegment(at: now)
        stopDisplayTimer()
        idleMonitor.stop()
    }

    func resumeSession() {
        guard sessionState == .paused else { return }
        activeRunStartedAt = Date()
        sessionState = .active
        monitor.start()
        startDisplayTimer()
        idleMonitor.start()
    }

    func endSession() {
        let now = Date()

        switch sessionState {
        case .idle:
            return
        case .active:
            if let runStart = activeRunStartedAt {
                accumulatedSessionDuration += now.timeIntervalSince(runStart)
            }
            activeRunStartedAt = nil
            monitor.stop()
            segmentBuilder.closeCurrentSegment(at: now)
            stopDisplayTimer()
            idleMonitor.stop()
        case .paused:
            break
        }

        finalizeSession(endedAt: now)
        buffer.clear()
        accumulatedSessionDuration = 0
        sessionState = .idle
    }

    private func idlePause(lastActivityAt: Date) {
        guard sessionState == .active, let runStart = activeRunStartedAt else { return }
        // Close at last user activity time, not at poll detection time.
        // This excludes the idle threshold period from segment and accumulated durations.
        let closeTime = lastActivityAt > runStart ? lastActivityAt : runStart
        accumulatedSessionDuration += closeTime.timeIntervalSince(runStart)
        activeRunStartedAt = nil
        stopDisplayTimer()
        segmentBuilder.closeCurrentSegment(at: closeTime)
        monitor.stop()
    }

    private func idleResume() {
        guard sessionState == .active, activeRunStartedAt == nil else { return }
        activeRunStartedAt = Date()
        startDisplayTimer()
        monitor.start()
    }

    private func startDisplayTimer() {
        stopDisplayTimer()
        liveClockTick = Date()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.liveClockTick = Date()
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func finalizeSession(endedAt: Date) {
        guard let startedAt = sessionStartedAt else { return }

        let session = TrackedSession(
            id: UUID(),
            startedAt: startedAt,
            endedAt: endedAt,
            segments: segmentBuilder.drainSegments()
        )

        let dayKey = Calendar.current.startOfDay(for: startedAt)
        if let idx = workDays.firstIndex(where: { $0.date == dayKey }) {
            workDays[idx].sessions.append(session)
        } else {
            workDays.append(WorkDayRecord(date: dayKey, sessions: [session]))
        }

        sessionStartedAt = nil
    }
}
