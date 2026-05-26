import Foundation
import Testing
@testable import MuxyCore

@Suite("ReconnectPolicy")
struct ReconnectPolicyTests {
    @Test("first attempts grow exponentially without jitter")
    func growsExponentially() {
        let policy = ReconnectPolicy(base: 0.5, cap: 30, jitter: 0)
        #expect(policy.delay(attempt: 0, randomZeroToOne: 0.5) == 0.5)
        #expect(policy.delay(attempt: 1, randomZeroToOne: 0.5) == 1.0)
        #expect(policy.delay(attempt: 2, randomZeroToOne: 0.5) == 2.0)
        #expect(policy.delay(attempt: 3, randomZeroToOne: 0.5) == 4.0)
        #expect(policy.delay(attempt: 4, randomZeroToOne: 0.5) == 8.0)
    }

    @Test("delay never exceeds cap")
    func respectsCap() {
        let policy = ReconnectPolicy(base: 0.5, cap: 30, jitter: 0)
        #expect(policy.delay(attempt: 100, randomZeroToOne: 0.5) == 30)
    }

    @Test("jitter shrinks delay when random is 0")
    func jitterMin() {
        let policy = ReconnectPolicy(base: 1, cap: 60, jitter: 0.3)
        let delay = policy.delay(attempt: 3, randomZeroToOne: 0)
        #expect(delay == 8 - 8 * 0.3)
    }

    @Test("jitter grows delay when random is 1")
    func jitterMax() {
        let policy = ReconnectPolicy(base: 1, cap: 60, jitter: 0.3)
        let delay = policy.delay(attempt: 3, randomZeroToOne: 1)
        #expect(delay == 8 + 8 * 0.3)
    }

    @Test("negative attempts treated as zero")
    func negativeAttempt() {
        let policy = ReconnectPolicy(base: 0.5, cap: 30, jitter: 0)
        #expect(policy.delay(attempt: -5, randomZeroToOne: 0.5) == 0.5)
    }
}
