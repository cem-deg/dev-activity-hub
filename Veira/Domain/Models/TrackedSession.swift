import Foundation

struct TrackedSession: Codable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let segments: [ActivitySegment]

    var segmentDuration: TimeInterval {
        segments.compactMap(\.duration).reduce(0, +)
    }

    var perAppDurations: [(bundleIdentifier: String, appName: String, duration: TimeInterval)] {
        var totals: [String: (appName: String, duration: TimeInterval)] = [:]
        for segment in segments {
            guard let d = segment.duration else { continue }
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
