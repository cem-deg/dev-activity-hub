import Foundation

struct ActivitySegment: Codable {
    let appName: String
    let bundleIdentifier: String
    let startTime: Date
    var endTime: Date?

    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }
}
