import Foundation

struct RecordMotion {
    private(set) var phase: Double = 0
    private(set) var speed: Double = 0
    private(set) var target: Double = 0
    private(set) var anchor: Double = 0
    private(set) var frozen = false
    private let smoothing = 0.7
    func value(at time: Double) -> Double {
        guard !frozen else { return phase }
        let elapsed = max(0, time - anchor)
        return phase + target * elapsed + (speed - target) * smoothing * (1 - exp(-elapsed / smoothing))
    }
    func velocity(at time: Double) -> Double {
        frozen ? 0 : target + (speed - target) * exp(-max(0, time - anchor) / smoothing)
    }
    func moving(at time: Double) -> Bool { !frozen && (target > 0 || velocity(at: time) > 0.02) }
    mutating func configure(rpm: Double, playing: Bool, reduced: Bool, at time: Double) {
        let value = value(at: time)
        let current = velocity(at: time)
        phase = value.truncatingRemainder(dividingBy: 360)
        speed = reduced ? 0 : current
        target = playing && !reduced ? (rpm.isFinite ? min(60, max(1, rpm)) : 6) * 6 : 0
        anchor = time
        frozen = reduced
    }
}
