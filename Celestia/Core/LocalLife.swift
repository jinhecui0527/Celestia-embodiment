import Foundation

/// Deterministic, seedable RNG so autonomic motion can be unit-tested.
struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Autonomic motion the body produces on its own: breathing, blinking, saccades and
/// idle sway. It keeps running when the gateway is silent or unreachable, so Cocoa
/// never freezes into a still image.
struct LocalLife: Sendable {
    struct Output: Equatable, Sendable {
        var breath: Double = 0
        var blink: Double = 0
        var gazeX: Double = 0
        var gazeY: Double = 0
        var headYaw: Double = 0
        var headPitch: Double = 0
        var headRoll: Double = 0
    }

    private(set) var output = Output()
    private var rng: SplitMix64
    private var time: Double = 0

    private var breathPhase: Double = 0

    private var nextBlinkAt: Double
    private var blinkStartedAt: Double?
    private var pendingDoubleBlink = false

    private var nextSaccadeAt: Double
    private var saccadeTarget: (x: Double, y: Double) = (0, 0)
    private var swaySeeds: (Double, Double, Double)

    static let blinkClose = 0.07
    static let blinkHold = 0.03
    static let blinkOpen = 0.13
    static var blinkDuration: Double { blinkClose + blinkHold + blinkOpen }

    init(seed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000)) {
        var rng = SplitMix64(seed: seed)
        nextBlinkAt = Double.random(in: 1.0...3.0, using: &rng)
        nextSaccadeAt = Double.random(in: 0.6...1.8, using: &rng)
        swaySeeds = (
            Double.random(in: 0...100, using: &rng),
            Double.random(in: 0...100, using: &rng),
            Double.random(in: 0...100, using: &rng)
        )
        self.rng = rng
    }

    /// Advances the simulation. `energy` (0...1) speeds up breath and blinks and
    /// widens idle motion; it comes from the gateway's continuous `energy` channel.
    mutating func advance(dt rawDt: Double, energy: Double) -> Output {
        let dt = min(max(rawDt, 0), 0.1)
        time += dt
        let e = min(max(energy, 0), 1)

        let breathPeriod = 5.2 - 2.0 * e
        breathPhase = (breathPhase + dt / breathPeriod).truncatingRemainder(dividingBy: 1)
        // Inhale is shorter than exhale; shape a skewed sine into 0...1.
        let skewed = breathPhase < 0.4 ? breathPhase / 0.4 * 0.5 : 0.5 + (breathPhase - 0.4) / 0.6 * 0.5
        output.breath = 0.5 - 0.5 * cos(skewed * 2 * .pi)

        output.blink = advanceBlink(energy: e)
        advanceSaccades(dt: dt, energy: e)

        let amp = 0.25 + 0.5 * e
        output.headYaw = amp * 0.12 * smoothNoise(time * 0.11 + swaySeeds.0)
        output.headPitch = amp * 0.08 * smoothNoise(time * 0.09 + swaySeeds.1) + 0.03 * (output.breath - 0.5)
        output.headRoll = amp * 0.06 * smoothNoise(time * 0.07 + swaySeeds.2)
        return output
    }

    private mutating func advanceBlink(energy: Double) -> Double {
        if blinkStartedAt == nil, time >= nextBlinkAt {
            blinkStartedAt = time
        }
        guard let start = blinkStartedAt else { return 0 }

        let t = time - start
        let value: Double
        if t < Self.blinkClose {
            value = easeInOut(t / Self.blinkClose)
        } else if t < Self.blinkClose + Self.blinkHold {
            value = 1
        } else if t < Self.blinkDuration {
            value = 1 - easeInOut((t - Self.blinkClose - Self.blinkHold) / Self.blinkOpen)
        } else {
            blinkStartedAt = nil
            if pendingDoubleBlink {
                pendingDoubleBlink = false
                nextBlinkAt = time + 0.12
            } else {
                let base = 4.5 - 2.0 * energy
                nextBlinkAt = time + Double.random(in: (base * 0.5)...(base * 1.5), using: &rng)
                pendingDoubleBlink = Double.random(in: 0...1, using: &rng) < 0.12
            }
            value = 0
        }
        return value
    }

    private mutating func advanceSaccades(dt: Double, energy: Double) {
        if time >= nextSaccadeAt {
            let reach = 0.18 + 0.25 * energy
            saccadeTarget = (
                Double.random(in: -reach...reach, using: &rng),
                Double.random(in: -reach * 0.6...reach * 0.6, using: &rng)
            )
            nextSaccadeAt = time + Double.random(in: 0.7...(3.2 - 1.4 * energy), using: &rng)
        }
        // Saccades are fast; follow the target with a short time constant.
        let k = 1 - exp(-dt / 0.035)
        output.gazeX += (saccadeTarget.x - output.gazeX) * k
        output.gazeY += (saccadeTarget.y - output.gazeY) * k
    }

    private func easeInOut(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    /// Cheap 1D coherent noise in -1...1 built from incommensurate sines.
    private func smoothNoise(_ x: Double) -> Double {
        (sin(x * 2.1) * 0.5 + sin(x * 3.7 + 1.3) * 0.3 + sin(x * 5.9 + 2.7) * 0.2)
    }
}
