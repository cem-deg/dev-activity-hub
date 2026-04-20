import Foundation

struct DaySummary: Identifiable {
    let date: Date
    let sessionCount: Int
    let totalDuration: TimeInterval

    var id: Date { date }
}
