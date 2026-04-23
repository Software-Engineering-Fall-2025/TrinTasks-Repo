import Foundation

final class RefreshService {
    private var activity: NSBackgroundActivityScheduler?
    private var interval: TimeInterval
    private let handler: () -> Void

    init(interval: TimeInterval, handler: @escaping () -> Void) {
        self.interval = interval
        self.handler = handler
    }

    func start() {
        let scheduler = NSBackgroundActivityScheduler(identifier: "com.trintasks.refresh")
        scheduler.repeats = true
        scheduler.interval = interval
        scheduler.qualityOfService = .utility
        scheduler.schedule { [weak self] completion in
            self?.handler()
            completion(.success)
        }
        activity = scheduler
    }

    func reschedule(interval newInterval: TimeInterval) {
        activity?.invalidate()
        interval = newInterval
        start()
    }

    deinit { activity?.invalidate() }
}
