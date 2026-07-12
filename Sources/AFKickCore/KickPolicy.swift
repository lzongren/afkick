/// Decides when to "kick" a camera's autofocus based on stream state transitions.
///
/// Pure state machine — no clocks, no hardware. Callers feed it observations
/// (`isRunning` at a timestamp) and act on the returned `Action`.
public struct KickPolicy {
    public enum Action: Equatable {
        case none
        /// Toggle autofocus at (not before) the given timestamp.
        case kick(at: Double)
    }

    private let delay: Double
    private let debounce: Double
    private var wasRunning = false
    private var lastKickTime: Double?
    /// Set when a kick is scheduled; cleared if the stream stops first.
    private var pendingKickArmed = false

    /// - Parameters:
    ///   - delay: seconds to wait after stream start before kicking, letting
    ///     the stream stabilize (exposure/format negotiation).
    ///   - debounce: minimum seconds between kicks, so apps that rapidly
    ///     close/reopen the device don't cause focus hunting.
    public init(delay: Double, debounce: Double = 0) {
        self.delay = delay
        self.debounce = debounce
    }

    public mutating func observe(
        isRunning: Bool, at now: Double, isFirstObservation: Bool = false
    ) -> Action {
        defer { wasRunning = isRunning }

        let started = isRunning && (!wasRunning || isFirstObservation)
        guard started else {
            if !isRunning { pendingKickArmed = false }
            return .none
        }

        if let last = lastKickTime, now - last < debounce {
            return .none
        }

        let fireAt = isFirstObservation ? now : now + delay
        lastKickTime = fireAt
        pendingKickArmed = true
        return .kick(at: fireAt)
    }

    /// Call when a scheduled kick's timer fires: returns false if the stream
    /// stopped in the meantime and the kick should be skipped.
    public mutating func shouldFire(at now: Double) -> Bool {
        defer { pendingKickArmed = false }
        return pendingKickArmed && wasRunning
    }
}
