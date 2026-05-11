import Foundation

enum SessionState {
    case idle
    case active
    case paused
    case pausedDueToInactivity

    var statusLabel: String {
        switch self {
        case .idle:                  return "No Active Session"
        case .active:                return "Session Active"
        case .paused:                return "Session Paused"
        case .pausedDueToInactivity: return "Paused — Inactivity"
        }
    }
}

final class AppState: ObservableObject {
    @Published private(set) var sessionState: SessionState = .idle
    @Published var hasCompletedOnboarding: Bool = {
        let defaults = UserDefaults.standard
        // Read from the new Veira key if it has been written before.
        if defaults.object(forKey: "com.veira.hasCompletedOnboarding") != nil {
            return defaults.bool(forKey: "com.veira.hasCompletedOnboarding")
        }
        // One-time migration: promote the legacy ProjectPulse key.
        if defaults.bool(forKey: "com.projectpulse.hasCompletedOnboarding") {
            defaults.set(true, forKey: "com.veira.hasCompletedOnboarding")
            return true
        }
        return false
    }()

    private let monitor = ActiveAppMonitor()
    private let segmentBuilder = ActivitySegmentBuilder()
    private var currentSessionId: UUID?
    private let idleMonitor = IdleMonitor(threshold: 600)

    // Finalization boundary — unchanged across pause/resume cycles
    private var sessionStartedAt: Date?

    // Runtime display state — separate from finalization
    private var activeRunStartedAt: Date?
    private var accumulatedSessionDuration: TimeInterval = 0

    // Open segment overlay — mirrors the builder's in-flight segment for live display
    private var openSegmentAppName: String?
    private var openSegmentBundleId: String?
    private var openSegmentStartTime: Date?

    @Published private(set) var liveClockTick: Date = Date()
    private var displayTimer: Timer?
    private var autosaveTimer: Timer?

    private var pauseReminderTimer: Timer?
    private var pauseStartedAt: Date?
    private var pauseReminderFired = false

    @Published private var workDays: [WorkDayRecord] = SessionStore.load()

    init() {
        monitor.onEvent = { [weak self] event in
            self?.segmentBuilder.handle(event)
            self?.openSegmentAppName = event.appName
            self?.openSegmentBundleId = event.bundleIdentifier
            self?.openSegmentStartTime = event.timestamp
        }
        idleMonitor.onIdleStarted = { [weak self] lastActivityAt in self?.idlePause(lastActivityAt: lastActivityAt) }
        idleMonitor.onIdleEnded   = { [weak self] in self?.handleIdleEnded() }
        ActivityNotifier.requestPermission()
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

    var currentStreakDays: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func dayDuration(_ date: Date) -> TimeInterval {
            workDays.first(where: { $0.date == date })
                .map { $0.sessions.reduce(0.0) { $0 + $1.segmentDuration } } ?? 0
        }

        let startDay = dayDuration(today) > 0
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today)!

        var streak = 0
        var day = startDay
        while dayDuration(day) > 0 {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
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

    var currentSessionAppTotals: [AppUsageTotal] {
        guard sessionState != .idle else { return [] }

        var accumulated: [String: (appName: String, duration: TimeInterval)] = [:]

        for segment in segmentBuilder.closedSegments {
            guard let duration = segment.duration else { continue }
            if accumulated[segment.bundleIdentifier] != nil {
                accumulated[segment.bundleIdentifier]!.duration += duration
            } else {
                accumulated[segment.bundleIdentifier] = (segment.appName, duration)
            }
        }

        if sessionState == .active,
           let appName = openSegmentAppName,
           let bundleId = openSegmentBundleId,
           let startTime = openSegmentStartTime {
            let elapsed = max(0, liveClockTick.timeIntervalSince(startTime))
            if accumulated[bundleId] != nil {
                accumulated[bundleId]!.duration += elapsed
            } else {
                accumulated[bundleId] = (appName, elapsed)
            }
        }

        return accumulated
            .map { AppUsageTotal(appName: $0.value.appName, bundleIdentifier: $0.key, totalDuration: $0.value.duration) }
            .sorted { $0.totalDuration > $1.totalDuration }
    }

    var topAppToday: (appName: String, duration: TimeInterval)? {
        guard let top = todayAppTotals.first else { return nil }
        return (top.appName, top.totalDuration)
    }

    var longestSessionToday: TimeInterval? {
        todayRecord?.sessions.map(\.segmentDuration).max()
    }

    var mostActiveDayThisWeek: (dayName: String, duration: TimeInterval)? {
        guard let best = weeklyDaySummaries.max(by: { $0.totalDuration < $1.totalDuration }),
              best.totalDuration > 0 else { return nil }
        return (Self.dayNameFormatter.string(from: best.date), best.totalDuration)
    }

    private static let dayNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    // MARK: - Onboarding

    func markOnboardingComplete() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "com.veira.hasCompletedOnboarding")
    }

    // MARK: - Session control

    func startSession() {
        guard sessionState == .idle else { return }
        cancelPauseReminder()
        let now = Date()
        sessionStartedAt = now
        activeRunStartedAt = now
        accumulatedSessionDuration = 0
        currentSessionId = UUID()
        sessionState = .active
        monitor.start()
        startDisplayTimer()
        startAutosaveTimer()
        idleMonitor.threshold = idleThresholdSeconds
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
        stopAutosaveTimer()
        performAutosave()
        idleMonitor.stop()
        startPauseReminder()
    }

    func resumeSession() {
        guard sessionState == .paused || sessionState == .pausedDueToInactivity else { return }
        cancelPauseReminder()
        activeRunStartedAt = Date()
        sessionState = .active
        monitor.start()
        startDisplayTimer()
        startAutosaveTimer()
        idleMonitor.threshold = idleThresholdSeconds
        idleMonitor.start()
    }

    func endSession() {
        cancelPauseReminder()
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
        case .paused, .pausedDueToInactivity:
            break
        }

        idleMonitor.stop()
        stopAutosaveTimer()
        finalizeSession(endedAt: now)
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
        sessionState = .pausedDueToInactivity
        // idleMonitor keeps running to detect user return for the notification
    }

    private func handleIdleEnded() {
        guard sessionState == .pausedDueToInactivity else { return }
        ActivityNotifier.notifyInactivityPause()
        idleMonitor.stop()
    }

    private var idleThresholdSeconds: TimeInterval {
        let minutes = UserDefaults.standard.integer(forKey: "com.veira.idleReminderMinutes")
        return TimeInterval((minutes > 0 ? minutes : 10) * 60)
    }

    private var pauseReminderThreshold: TimeInterval {
        let minutes = UserDefaults.standard.integer(forKey: "com.veira.pauseReminderMinutes")
        return TimeInterval((minutes > 0 ? minutes : 5) * 60)
    }

    private func startPauseReminder() {
        pauseReminderFired = false
        pauseStartedAt = Date()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkPauseReminder()
        }
        RunLoop.main.add(timer, forMode: .common)
        pauseReminderTimer = timer
    }

    private func cancelPauseReminder() {
        pauseReminderTimer?.invalidate()
        pauseReminderTimer = nil
        pauseStartedAt = nil
        pauseReminderFired = false
    }

    private func checkPauseReminder() {
        guard !pauseReminderFired, let startedAt = pauseStartedAt else { return }
        guard idleMonitor.isUserActive else {
            cancelPauseReminder()
            return
        }
        guard Date().timeIntervalSince(startedAt) >= pauseReminderThreshold else { return }
        pauseReminderFired = true
        pauseReminderTimer?.invalidate()
        pauseReminderTimer = nil
        ActivityNotifier.notifyPausedButActive()
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

    private func startAutosaveTimer() {
        stopAutosaveTimer()
        let timer = Timer(timeInterval: 12, repeats: true) { [weak self] _ in
            self?.performAutosave()
        }
        RunLoop.main.add(timer, forMode: .common)
        autosaveTimer = timer
    }

    private func stopAutosaveTimer() {
        autosaveTimer?.invalidate()
        autosaveTimer = nil
    }

    private func performAutosave() {
        guard let startedAt = sessionStartedAt,
              let sessionId = currentSessionId else { return }

        let now = Date()
        let partial = TrackedSession(
            id: sessionId,
            startedAt: startedAt,
            endedAt: now,
            segments: segmentBuilder.snapshotSegments(at: now)
        )

        let dayKey = Calendar.current.startOfDay(for: startedAt)
        var snapshot = workDays
        if let idx = snapshot.firstIndex(where: { $0.date == dayKey }) {
            if let existing = snapshot[idx].sessions.firstIndex(where: { $0.id == sessionId }) {
                snapshot[idx].sessions[existing] = partial
            } else {
                snapshot[idx].sessions.append(partial)
            }
        } else {
            snapshot.append(WorkDayRecord(date: dayKey, sessions: [partial]))
        }

        SessionStore.saveAsync(snapshot)
    }

    private func finalizeSession(endedAt: Date) {
        guard let startedAt = sessionStartedAt else { return }

        let session = TrackedSession(
            id: currentSessionId ?? UUID(),
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
        currentSessionId = nil
        SessionStore.saveAsync(workDays)
    }
}
