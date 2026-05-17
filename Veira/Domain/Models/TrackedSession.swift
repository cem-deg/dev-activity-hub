import Foundation

struct TrackedSession: Codable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let segments: [ActivitySegment]
    // Optional fields — absent in workdays.json written before these were added.
    // Missing keys decode to nil; nil mode is treated as .appTracking everywhere.
    var title: String?
    var mode: SessionMode?
    var targetDuration: TimeInterval?   // nil for no target; absent in older workdays.json
    var projectName: String?            // optional user-assigned project/label

    // Sentinel bundle ID written into ActivitySegments for focus/desk sessions.
    // Excluded from per-app usage totals so focus time does not appear as a fake app.
    static let focusBundleID = "com.veira.focus"

    // Stable appName written into focus ActivitySegments.
    // The user-entered title is stored only in TrackedSession.title, not in segment data,
    // so renaming a session does not leave stale user text in the JSON segments array.
    static let focusSegmentName = "Focus"

    // Custom init so existing call sites (id:startedAt:endedAt:segments:) compile without change.
    init(
        id: UUID,
        startedAt: Date,
        endedAt: Date,
        segments: [ActivitySegment],
        title: String? = nil,
        mode: SessionMode? = nil,
        targetDuration: TimeInterval? = nil,
        projectName: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.segments = segments
        self.title = title
        self.mode = mode
        self.targetDuration = targetDuration
        self.projectName = projectName
    }

    // MARK: - Derived properties

    var trackingMode: SessionMode { mode ?? .appTracking }
    var isFocusSession: Bool { trackingMode == .focus }

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        if isFocusSession { return "Desk Session" }
        return appSummary.isEmpty ? "Computer Session" : appSummary
    }

    var segmentDuration: TimeInterval {
        segments.compactMap(\.duration).reduce(0, +)
    }

    // Per-app breakdown excluding focus sentinel segments.
    // Focus time is counted in segmentDuration but not attributed to a fake "app" entry.
    var perAppDurations: [(bundleIdentifier: String, appName: String, duration: TimeInterval)] {
        var totals: [String: (appName: String, duration: TimeInterval)] = [:]
        for segment in segments {
            guard let d = segment.duration else { continue }
            guard segment.bundleIdentifier != Self.focusBundleID else { continue }
            if totals[segment.bundleIdentifier] != nil {
                totals[segment.bundleIdentifier]!.duration += d
            } else {
                totals[segment.bundleIdentifier] = (segment.appName, d)
            }
        }
        return totals
            .map { (bundleIdentifier: $0.key, appName: $0.value.appName, duration: $0.value.duration) }
            .sorted { $0.duration > $1.duration }
    }

    var appSummary: String {
        let names = perAppDurations.map(\.appName)
        switch names.count {
        case 0:  return ""
        case 1:  return names[0]
        case 2:  return "\(names[0]) + \(names[1])"
        default: return "\(names[0]) + \(names.count - 1) more"
        }
    }
}
