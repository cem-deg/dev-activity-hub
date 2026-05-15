import AppKit
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
    @Published var selectedStartMode: SessionMode = .appTracking
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

    // Focus/desk session state
    private var currentSessionMode: SessionMode = .appTracking
    private var currentFocusTitle: String? = nil

    @Published private(set) var liveClockTick: Date = Date()
    private var displayTimer: Timer?
    private var autosaveTimer: Timer?

    private var pauseReminderTimer: Timer?
    private var pauseStartedAt: Date?
    private var pauseReminderFired = false

    @Published private var workDays: [WorkDayRecord] = SessionStore.load()

    // Retained so the observer can be removed if AppState is ever deallocated.
    private var terminateObserver: NSObjectProtocol?

    init() {
        monitor.onEvent = { [weak self] event in
            guard let self else { return }
            guard segmentBuilder.handle(event) else { return }
            openSegmentAppName = event.appName
            openSegmentBundleId = event.bundleIdentifier
            openSegmentStartTime = event.timestamp
        }
        idleMonitor.onIdleStarted = { [weak self] lastActivityAt in self?.idlePause(lastActivityAt: lastActivityAt) }
        idleMonitor.onIdleEnded   = { [weak self] in self?.handleIdleEnded() }
        ActivityNotifier.requestPermission()

        // Cover quit paths that bypass the menu button (Cmd+Q, Apple menu).
        // queue: nil runs the block synchronously on the posting thread (main thread),
        // ensuring the write completes before applicationWillTerminate returns.
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.prepareForQuit()
        }
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

    /// Mode of the currently in-progress session. Returns .appTracking when idle.
    var activeSessionMode: SessionMode { currentSessionMode }

    /// Title of the currently in-progress focus session, or nil when idle / app-tracking.
    var activeFocusTitle: String? { currentFocusTitle }

    /// Total elapsed duration of the current session including the active run interval.
    /// Does not clip to today — used by the focus timer window to show total session time.
    var currentTotalSessionDuration: TimeInterval {
        guard sessionState != .idle else { return 0 }
        let elapsed = activeRunStartedAt.map { max(0, liveClockTick.timeIntervalSince($0)) } ?? 0
        return accumulatedSessionDuration + elapsed
    }

    // The portion of the current in-progress session that falls within today's calendar day.
    // Clamps each closed segment and the open segment to [todayStart, todayEnd).
    // Used by the menu bar Today display so cross-midnight sessions don't inflate today's number.
    var currentSessionTodayDuration: TimeInterval {
        guard sessionState != .idle else { return 0 }
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        guard let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) else { return 0 }

        var total: TimeInterval = 0

        for segment in segmentBuilder.closedSegments {
            guard let end = segment.endTime else { continue }
            let clampedStart = max(segment.startTime, todayStart)
            let clampedEnd   = min(end, todayEnd)
            if clampedEnd > clampedStart {
                total += clampedEnd.timeIntervalSince(clampedStart)
            }
        }

        if sessionState == .active, let openStart = openSegmentStartTime {
            let clampedStart = max(openStart, todayStart)
            let clampedEnd   = min(liveClockTick, todayEnd)
            if clampedEnd > clampedStart {
                total += clampedEnd.timeIntervalSince(clampedStart)
            }
        }

        return total
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

    // App usage totals for today. Excludes focus-session sentinel segments so focus time
    // does not appear as a fake app entry in the per-app breakdown.
    var todayAppTotals: [AppUsageTotal] {
        guard let record = todayRecord else { return [] }

        var accumulated: [String: (appName: String, duration: TimeInterval)] = [:]

        for session in record.sessions {
            for segment in session.segments {
                guard let duration = segment.duration else { continue }
                guard segment.bundleIdentifier != TrackedSession.focusBundleID else { continue }
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

    // Per-app totals for the current in-progress session.
    // Excludes focus sentinel segments; returns empty for focus sessions.
    var currentSessionAppTotals: [AppUsageTotal] {
        guard sessionState != .idle else { return [] }

        var accumulated: [String: (appName: String, duration: TimeInterval)] = [:]

        for segment in segmentBuilder.closedSegments {
            guard let duration = segment.duration else { continue }
            guard segment.bundleIdentifier != TrackedSession.focusBundleID else { continue }
            if accumulated[segment.bundleIdentifier] != nil {
                accumulated[segment.bundleIdentifier]!.duration += duration
            } else {
                accumulated[segment.bundleIdentifier] = (segment.appName, duration)
            }
        }

        if sessionState == .active,
           let appName = openSegmentAppName,
           let bundleId = openSegmentBundleId,
           bundleId != TrackedSession.focusBundleID,
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

    // MARK: - Quit preparation

    // Finalizes any in-progress session and writes the workDays snapshot to disk synchronously.
    //
    // Idempotent: sessionStartedAt is cleared on the first call, so a second call (e.g.
    // from willTerminateNotification after the menu button already ran this) skips session
    // finalization and just re-issues the synchronous write — safe, no duplicate sessions.
    func prepareForQuit() {
        // Stop all timers and monitors first so no new saveAsync calls can be queued
        // between here and the saveFinal call at the end.
        cancelPauseReminder()
        stopAutosaveTimer()
        stopDisplayTimer()
        // Only stop monitor/idleMonitor if they were started (app tracking mode).
        if currentSessionMode == .appTracking {
            monitor.stop()
            idleMonitor.stop()
        }

        // sessionStartedAt is the authoritative indicator that a session is open.
        if let startedAt = sessionStartedAt {
            let now = Date()

            // Close the open segment if the session is currently active.
            if sessionState == .active {
                if let runStart = activeRunStartedAt {
                    accumulatedSessionDuration += now.timeIntervalSince(runStart)
                }
                activeRunStartedAt = nil
                segmentBuilder.closeCurrentSegment(at: now)
                openSegmentAppName = nil
                openSegmentBundleId = nil
                openSegmentStartTime = nil
            }

            let session = TrackedSession(
                id: currentSessionId ?? UUID(),
                startedAt: startedAt,
                endedAt: now,
                segments: segmentBuilder.drainSegments(),
                title: currentFocusTitle,
                mode: currentSessionMode
            )

            for (dayKey, slice) in splitSessionByDay(session) {
                if let idx = workDays.firstIndex(where: { $0.date == dayKey }) {
                    workDays[idx].sessions.append(slice)
                } else {
                    workDays.append(WorkDayRecord(date: dayKey, sessions: [slice]))
                }
            }

            // Clear so a second call to prepareForQuit skips this block.
            sessionStartedAt = nil
            currentSessionId = nil
            currentSessionMode = .appTracking
            currentFocusTitle = nil
        }

        // Write synchronously. saveFinal advances the generation counter (poisoning any
        // remaining queued async blocks) then runs writeQueue.sync, which waits for any
        // currently-executing async block to drain before writing the final snapshot.
        SessionStore.saveFinal(workDays)
    }

    // MARK: - Session control

    func startSession() {
        guard sessionState == .idle else { return }
        currentSessionMode = .appTracking
        currentFocusTitle = nil
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

    // Starts a Focus/Desk session with an optional title.
    // Does not start active app tracking or idle detection.
    // A synthetic segment with the focus sentinel bundle ID is opened in the segment builder
    // so that the existing autosave, midnight-split, and quit-finalization paths work unchanged.
    func startFocusSession(title: String) {
        guard sessionState == .idle else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        currentFocusTitle = trimmed.isEmpty ? nil : trimmed
        currentSessionMode = .focus
        cancelPauseReminder()
        let now = Date()
        sessionStartedAt = now
        activeRunStartedAt = now
        accumulatedSessionDuration = 0
        currentSessionId = UUID()
        sessionState = .active

        // Open a synthetic focus segment so the segment builder can track this run interval.
        // Use the stable focusSegmentName — NOT the user-entered title — so user text is
        // stored only in TrackedSession.title and never embedded in segment JSON data.
        segmentBuilder.handle(ActivityEvent(
            appName: TrackedSession.focusSegmentName,
            bundleIdentifier: TrackedSession.focusBundleID,
            timestamp: now
        ))
        openSegmentAppName = TrackedSession.focusSegmentName
        openSegmentBundleId = TrackedSession.focusBundleID
        openSegmentStartTime = now

        startDisplayTimer()
        startAutosaveTimer()
        // No monitor.start() or idleMonitor.start() — focus sessions are user-controlled.
    }

    func pauseSession() {
        guard sessionState == .active else { return }
        let now = Date()
        if let runStart = activeRunStartedAt {
            accumulatedSessionDuration += now.timeIntervalSince(runStart)
        }
        activeRunStartedAt = nil
        sessionState = .paused
        segmentBuilder.closeCurrentSegment(at: now)
        openSegmentAppName = nil
        openSegmentBundleId = nil
        openSegmentStartTime = nil
        stopDisplayTimer()
        stopAutosaveTimer()
        performAutosave()

        if currentSessionMode == .appTracking {
            monitor.stop()
            idleMonitor.stop()
            startPauseReminder()
        }
        // Focus sessions: no monitor/idleMonitor to stop, no pause reminder needed.
    }

    func resumeSession() {
        guard sessionState == .paused || sessionState == .pausedDueToInactivity else { return }
        cancelPauseReminder()
        let now = Date()
        activeRunStartedAt = now
        sessionState = .active
        startDisplayTimer()
        startAutosaveTimer()

        if currentSessionMode == .appTracking {
            monitor.start()
            idleMonitor.threshold = idleThresholdSeconds
            idleMonitor.start()
        } else {
            // Focus: re-open a synthetic segment for the new run interval.
            // Use the stable focusSegmentName — NOT the user-entered title.
            segmentBuilder.handle(ActivityEvent(
                appName: TrackedSession.focusSegmentName,
                bundleIdentifier: TrackedSession.focusBundleID,
                timestamp: now
            ))
            openSegmentAppName = TrackedSession.focusSegmentName
            openSegmentBundleId = TrackedSession.focusBundleID
            openSegmentStartTime = now
        }
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
            segmentBuilder.closeCurrentSegment(at: now)
            openSegmentAppName = nil
            openSegmentBundleId = nil
            openSegmentStartTime = nil
            stopDisplayTimer()
            if currentSessionMode == .appTracking {
                monitor.stop()
            }
        case .paused, .pausedDueToInactivity:
            break
        }

        if currentSessionMode == .appTracking {
            idleMonitor.stop()
        }
        stopAutosaveTimer()
        finalizeSession(endedAt: now)
        accumulatedSessionDuration = 0
        sessionState = .idle
        // Reset focus state after finalizeSession has captured title/mode.
        currentSessionMode = .appTracking
        currentFocusTitle = nil
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
        openSegmentAppName = nil
        openSegmentBundleId = nil
        openSegmentStartTime = nil
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

    // MARK: - Session rename

    // Updates the title of all slices that share the given session id (cross-midnight sessions
    // produce multiple slices). Persists immediately via the async write path.
    func renameSession(id: UUID, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var changed = false
        for i in workDays.indices {
            for j in workDays[i].sessions.indices where workDays[i].sessions[j].id == id {
                guard workDays[i].sessions[j].title != trimmed else { continue }
                workDays[i].sessions[j].title = trimmed
                changed = true
            }
        }
        guard changed else { return }
        SessionStore.saveAsync(workDays)
    }

    // MARK: - Persistence helpers

    // Splits a TrackedSession into per-calendar-day slices.
    // Each ActivitySegment is cut at local midnight boundaries; the resulting sub-segments
    // are grouped by startOfDay. One TrackedSession per day is returned, sharing the
    // original session id so autosave upserts work correctly across saves.
    // If the session has no segments with a valid endTime, the original session is returned
    // under startedAt's day (preserves prior behaviour for zero-activity sessions).
    private func splitSessionByDay(_ session: TrackedSession) -> [(date: Date, session: TrackedSession)] {
        let calendar = Calendar.current
        var daySegments: [Date: [ActivitySegment]] = [:]

        for segment in session.segments {
            guard let endTime = segment.endTime, endTime > segment.startTime else { continue }
            var cursor = segment.startTime
            while cursor < endTime {
                let dayKey = calendar.startOfDay(for: cursor)
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayKey),
                      nextDay > cursor else { break }
                let sliceEnd = min(endTime, nextDay)
                daySegments[dayKey, default: []].append(ActivitySegment(
                    appName: segment.appName,
                    bundleIdentifier: segment.bundleIdentifier,
                    startTime: cursor,
                    endTime: sliceEnd
                ))
                if sliceEnd >= endTime { break }
                cursor = nextDay
            }
        }

        guard !daySegments.isEmpty else {
            let dayKey = calendar.startOfDay(for: session.startedAt)
            return [(date: dayKey, session: session)]
        }

        return daySegments.map { dayKey, slices in
            let sorted = slices.sorted { $0.startTime < $1.startTime }
            let sliceStart   = sorted.first?.startTime ?? dayKey
            let sliceEnd     = sorted.compactMap(\.endTime).last ?? sliceStart
            return (date: dayKey, session: TrackedSession(
                id: session.id,
                startedAt: sliceStart,
                endedAt: sliceEnd,
                segments: sorted,
                title: session.title,
                mode: session.mode
            ))
        }.sorted { $0.date < $1.date }
    }

    private func performAutosave() {
        guard let startedAt = sessionStartedAt,
              let sessionId = currentSessionId else { return }

        let now = Date()
        let partial = TrackedSession(
            id: sessionId,
            startedAt: startedAt,
            endedAt: now,
            segments: segmentBuilder.snapshotSegments(at: now),
            title: currentFocusTitle,
            mode: currentSessionMode
        )

        var snapshot = workDays
        for (dayKey, slice) in splitSessionByDay(partial) {
            if let idx = snapshot.firstIndex(where: { $0.date == dayKey }) {
                if let existing = snapshot[idx].sessions.firstIndex(where: { $0.id == sessionId }) {
                    snapshot[idx].sessions[existing] = slice
                } else {
                    snapshot[idx].sessions.append(slice)
                }
            } else {
                snapshot.append(WorkDayRecord(date: dayKey, sessions: [slice]))
            }
        }

        SessionStore.saveAsync(snapshot)
    }

    private func finalizeSession(endedAt: Date) {
        guard let startedAt = sessionStartedAt else { return }

        let session = TrackedSession(
            id: currentSessionId ?? UUID(),
            startedAt: startedAt,
            endedAt: endedAt,
            segments: segmentBuilder.drainSegments(),
            title: currentFocusTitle,
            mode: currentSessionMode
        )

        for (dayKey, slice) in splitSessionByDay(session) {
            if let idx = workDays.firstIndex(where: { $0.date == dayKey }) {
                workDays[idx].sessions.append(slice)
            } else {
                workDays.append(WorkDayRecord(date: dayKey, sessions: [slice]))
            }
        }

        sessionStartedAt = nil
        currentSessionId = nil
        SessionStore.saveAsync(workDays)
    }
}
