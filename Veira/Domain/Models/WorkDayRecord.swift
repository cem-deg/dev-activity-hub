import Foundation

struct WorkDayRecord: Codable {
    let date: Date
    var sessions: [TrackedSession]
}
