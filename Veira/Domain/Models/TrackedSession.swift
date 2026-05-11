import Foundation

struct TrackedSession: Codable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let segments: [ActivitySegment]

    var segmentDuration: TimeInterval {
        segments.compactMap(\.duration).reduce(0, +)
    }

    var perAppDurations: [(appName: String, duration: TimeInterval)] {
        var totals: [String: TimeInterval] = [:]
        for segment in segments {
            guard let d = segment.duration else { continue }
            totals[segment.appName, default: 0] += d
        }
        return totals.map { ($0.key, $0.value) }.sorted { $0.duration > $1.duration }
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
