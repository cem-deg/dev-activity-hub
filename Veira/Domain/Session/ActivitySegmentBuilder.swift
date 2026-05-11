import Foundation

final class ActivitySegmentBuilder {
    private(set) var closedSegments: [ActivitySegment] = []
    private var openSegment: ActivitySegment?

    func handle(_ event: ActivityEvent) {
        if var current = openSegment {
            current.endTime = event.timestamp
            closedSegments.append(current)
        }
        openSegment = ActivitySegment(
            appName: event.appName,
            bundleIdentifier: event.bundleIdentifier,
            startTime: event.timestamp
        )
    }

    func closeCurrentSegment(at time: Date) {
        guard var current = openSegment else { return }
        current.endTime = time
        closedSegments.append(current)
        openSegment = nil
    }

    func snapshotSegments(at time: Date) -> [ActivitySegment] {
        guard var open = openSegment else { return closedSegments }
        open.endTime = time
        return closedSegments + [open]
    }

    func drainSegments() -> [ActivitySegment] {
        let drained = closedSegments
        closedSegments.removeAll()
        return drained
    }
}
