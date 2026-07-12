import Testing
@testable import AFKickCore

@Suite("KickPolicy")
struct KickPolicyTests {
    @Test("idle -> streaming schedules a kick after the configured delay")
    func streamStartSchedulesKick() {
        var policy = KickPolicy(delay: 1.5)
        let action = policy.observe(isRunning: true, at: 100.0)
        #expect(action == .kick(at: 101.5))
    }

    @Test("already streaming on first observation kicks immediately")
    func alreadyStreamingKicksImmediately() {
        var policy = KickPolicy(delay: 1.5)
        let action = policy.observe(isRunning: true, at: 0.0, isFirstObservation: true)
        #expect(action == .kick(at: 0.0))
    }

    @Test("idle on first observation does nothing")
    func idleFirstObservationDoesNothing() {
        var policy = KickPolicy(delay: 1.5)
        let action = policy.observe(isRunning: false, at: 0.0, isFirstObservation: true)
        #expect(action == .none)
    }

    @Test("streaming -> streaming (no transition) does nothing")
    func noTransitionNoKick() {
        var policy = KickPolicy(delay: 1.5)
        _ = policy.observe(isRunning: true, at: 100.0)
        let action = policy.observe(isRunning: true, at: 100.5)
        #expect(action == .none)
    }

    @Test("streaming -> idle does nothing but re-arms")
    func stopReArms() {
        var policy = KickPolicy(delay: 1.5)
        _ = policy.observe(isRunning: true, at: 100.0)
        let stop = policy.observe(isRunning: false, at: 200.0)
        #expect(stop == .none)
        let restart = policy.observe(isRunning: true, at: 300.0)
        #expect(restart == .kick(at: 301.5))
    }

    @Test("rapid stop/start flapping within debounce window kicks only once")
    func debounce() {
        var policy = KickPolicy(delay: 1.5, debounce: 5.0)
        _ = policy.observe(isRunning: true, at: 100.0)   // kick scheduled at 101.5
        _ = policy.observe(isRunning: false, at: 102.0)  // stopped
        let action = policy.observe(isRunning: true, at: 103.0) // restarted 1s later, within 5s debounce
        #expect(action == .none)
        // after the debounce window, kicks resume
        _ = policy.observe(isRunning: false, at: 110.0)
        let later = policy.observe(isRunning: true, at: 120.0)
        #expect(later == .kick(at: 121.5))
    }

    @Test("kick should be skipped if stream stopped before the delayed kick fires")
    func confirmKickChecksStillRunning() {
        var policy = KickPolicy(delay: 1.5)
        _ = policy.observe(isRunning: true, at: 100.0)
        _ = policy.observe(isRunning: false, at: 100.5)
        #expect(policy.shouldFire(at: 101.5) == false)
    }

    @Test("kick fires when stream is still running at the scheduled time")
    func kickFiresWhenStillRunning() {
        var policy = KickPolicy(delay: 1.5)
        _ = policy.observe(isRunning: true, at: 100.0)
        #expect(policy.shouldFire(at: 101.5) == true)
    }

    @Test("zero delay kicks at observation time")
    func zeroDelay() {
        var policy = KickPolicy(delay: 0)
        let action = policy.observe(isRunning: true, at: 42.0)
        #expect(action == .kick(at: 42.0))
    }
}
