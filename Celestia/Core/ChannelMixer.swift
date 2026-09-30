import Foundation

/// Blends gateway targets, local autonomic life and local perception (the viewer's
/// finger or face) into the final channels the renderer draws each frame.
struct ChannelMixer: Sendable {
    /// After this long without a gateway patch, targets relax back to neutral so a
    /// dropped connection never leaves her frozen mid-word.
    var relaxAfter: Double = 2.5

    private(set) var target = PresenceChannels.neutral
    private(set) var smoothed = PresenceChannels.neutral
    private var ease: [ChannelKey: Double] = [:]
    private var secondsSincePatch: Double = .infinity
    private var life: LocalLife

    /// Normalized point in -1...1 the viewer is at (touch location, later face tracking).
    var viewerFocus: (x: Double, y: Double)?

    init(seed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000)) {
        life = LocalLife(seed: seed)
    }

    mutating func apply(_ patch: ChannelPatch) {
        for (key, value) in patch.values {
            target[key] = value
            if let e = patch.ease { ease[key] = max(e, 0.001) } else { ease[key] = nil }
        }
        secondsSincePatch = 0
    }

    mutating func advance(dt rawDt: Double) -> PresenceChannels {
        let dt = min(max(rawDt, 0), 0.1)
        secondsSincePatch += dt
        if secondsSincePatch > relaxAfter {
            target = relaxed(target, dt: dt)
        }

        for key in ChannelKey.allCases {
            let tau = ease[key] ?? key.defaultEase
            let k = 1 - exp(-dt / tau)
            smoothed[key] = smoothed[key] + (target[key] - smoothed[key]) * k
        }

        let auto = life.advance(dt: dt, energy: smoothed.energy)
        var out = smoothed
        out.breath = auto.breath
        out.blink = max(auto.blink, smoothed.blink)

        var baseGazeX = smoothed.gazeX
        var baseGazeY = smoothed.gazeY
        if let focus = viewerFocus {
            let pull = 0.35 + 0.65 * smoothed.attention
            baseGazeX += (focus.x - baseGazeX) * pull
            baseGazeY += (focus.y - baseGazeY) * pull
            out.headYaw = ChannelKey.headYaw.clamp(smoothed.headYaw + focus.x * 0.25 * pull)
            out.headPitch = ChannelKey.headPitch.clamp(smoothed.headPitch + focus.y * 0.15 * pull)
        }
        let wander = 1 - 0.6 * smoothed.attention
        out.gazeX = ChannelKey.gazeX.clamp(baseGazeX + auto.gazeX * wander)
        out.gazeY = ChannelKey.gazeY.clamp(baseGazeY + auto.gazeY * wander)
        out.headYaw = ChannelKey.headYaw.clamp(out.headYaw + auto.headYaw)
        out.headPitch = ChannelKey.headPitch.clamp(out.headPitch + auto.headPitch)
        out.headRoll = ChannelKey.headRoll.clamp(out.headRoll + auto.headRoll)
        return out
    }

    private func relaxed(_ channels: PresenceChannels, dt: Double) -> PresenceChannels {
        var c = channels
        let k = 1 - exp(-dt / 0.6)
        for key in ChannelKey.allCases {
            let rest = PresenceChannels.neutral[key]
            c[key] = c[key] + (rest - c[key]) * k
        }
        return c
    }
}
