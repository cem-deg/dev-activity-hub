import Foundation

struct AppUsageTotal: Identifiable {
    let appName: String
    let bundleIdentifier: String
    let totalDuration: TimeInterval

    var id: String { bundleIdentifier }
}
