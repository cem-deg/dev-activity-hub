import Foundation

final class ActivitySegmentBuilder {
    private(set) var closedSegments: [ActivitySegment] = []
    private var openSegment: ActivitySegment?

    @discardableResult
    func handle(_ event: ActivityEvent) -> Bool {
        if var current = openSegment {
            if current.appName == event.appName,
               current.bundleIdentifier == event.bundleIdentifier {
                return false
            }

            current.endTime = event.timestamp
            if event.timestamp > current.startTime {
                closedSegments.append(current)
            }
        }
        openSegment = ActivitySegment(
            appName: event.appName,
            bundleIdentifier: event.bundleIdentifier,
            startTime: event.timestamp
        )
        return true
    }

    func closeCurrentSegment(at time: Date) {
        guard var current = openSegment else { return }
        current.endTime = time
        if time > current.startTime {
            closedSegments.append(current)
        }
        openSegment = nil
    }

    func snapshotSegments(at time: Date) -> [ActivitySegment] {
        guard var open = openSegment else { return closedSegments }
        open.endTime = time
        guard time > open.startTime else { return closedSegments }
        return closedSegments + [open]
    }

    func drainSegments() -> [ActivitySegment] {
        let drained = closedSegments
        closedSegments.removeAll()
        return drained
    }
}
