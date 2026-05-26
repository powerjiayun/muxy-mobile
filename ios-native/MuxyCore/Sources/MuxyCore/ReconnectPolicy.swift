import Foundation

public struct ReconnectPolicy: Sendable, Equatable {
    public var base: TimeInterval
    public var cap: TimeInterval
    public var jitter: Double

    public init(base: TimeInterval = 0.5, cap: TimeInterval = 30, jitter: Double = 0.3) {
        self.base = base
        self.cap = cap
        self.jitter = max(0, min(jitter, 1))
    }

    public func delay(attempt: Int, randomZeroToOne: Double = Double.random(in: 0..<1)) -> TimeInterval {
        let safeAttempt = max(0, attempt)
        let exponent = min(31, safeAttempt)
        let raw = base * pow(2, Double(exponent))
        let capped = min(cap, raw)
        let jitterRange = capped * jitter
        let offset = (randomZeroToOne * 2 - 1) * jitterRange
        return max(0, capped + offset)
    }
}
