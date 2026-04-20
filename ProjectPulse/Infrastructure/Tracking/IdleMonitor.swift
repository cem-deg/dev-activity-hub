import CoreGraphics
import Foundation

final class IdleMonitor {
    var onIdleStarted: ((Date) -> Void)?
    var onIdleEnded: (() -> Void)?

    private let threshold: TimeInterval
    private var pollTimer: Timer?
    private var isIdle = false

    init(threshold: TimeInterval = 180) {
        self.threshold = threshold
    }

    func start() {
        guard pollTimer == nil else { return }
        isIdle = false
        let timer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        isIdle = false
    }

    private func poll() {
        // kCGAnyInputEventType (UInt32.max) — time since any keyboard/mouse/tablet input
        guard let anyInputEvent = CGEventType(rawValue: UInt32.max) else {
            return
        }

        let secondsIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: anyInputEvent
        )

        if !isIdle && secondsIdle >= threshold {
            isIdle = true
            let lastActivityTime = Date().addingTimeInterval(-secondsIdle)
            onIdleStarted?(lastActivityTime)
        } else if isIdle && secondsIdle < threshold {
            isIdle = false
            onIdleEnded?()
        }
    }

    deinit { stop() }
}
