import Foundation

final class ActivityEventBuffer {
    private(set) var events: [ActivityEvent] = []

    func append(_ event: ActivityEvent) {
        events.append(event)
    }

    func clear() {
        events.removeAll()
    }
}
