import Foundation

// Distinguishes between computer/app tracking sessions and manual focus/desk sessions.
// Stored as an optional on TrackedSession: nil decodes as .appTracking for backward
// compatibility with workdays.json written before this field existed.
enum SessionMode: String, Codable, Equatable {
    case appTracking
    case focus
}
