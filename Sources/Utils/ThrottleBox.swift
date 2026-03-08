import Foundation

/// A thread-safe timestamp-based throttle guard.
/// Uses `NSLock` for lightweight synchronisation.
final class ThrottleBox: @unchecked Sendable {
    private let interval: TimeInterval
    private var lastFired: Date = .distantPast
    private let lock = NSLock()

    init(interval: TimeInterval) {
        self.interval = interval
    }

    /// Returns `true` if enough time has passed since the last approved call.
    func shouldUpdate() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        if now.timeIntervalSince(lastFired) >= interval {
            lastFired = now
            return true
        }
        return false
    }
}

/// Thread-safe accumulator for scan progress metrics.
/// Always accepts data so nothing is lost; UI reads are throttled separately.
final class ProgressAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var _bytes: Int64 = 0
    private var _files: Int = 0
    private var _dirs: Int = 0

    func add(bytes: Int64, files: Int) {
        lock.lock()
        _bytes += bytes
        _files += files
        _dirs += 1
        lock.unlock()
    }

    func snapshot() -> (bytes: Int64, files: Int, dirs: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (_bytes, _files, _dirs)
    }
}
