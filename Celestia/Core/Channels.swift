import Foundation

/// The continuous channels that drive Cocoa's body on this device.
///
/// There is deliberately no discrete emotion enum: the gateway (her brain) streams
/// partial channel values, the device adds its own autonomic life on top, and the
/// renderer only ever sees these numbers.
struct PresenceChannels: Equatable, Codable, Sendable {
    var breath: Double = 0
    var blink: Double = 0
    var gazeX: Double = 0
    var gazeY: Double = 0
    var mouthOpen: Double = 0
    var mouthSmile: Double = 0.15
    var browRaise: Double = 0
    var headYaw: Double = 0
    var headPitch: Double = 0
    var headRoll: Double = 0
    var energy: Double = 0.5
    var warmth: Double = 0.5
    var attention: Double = 0.5

    static let neutral = PresenceChannels()

    subscript(key: ChannelKey) -> Double {
        get { self[keyPath: key.keyPath] }
        set { self[keyPath: key.keyPath] = key.clamp(newValue) }
    }
}

enum ChannelKey: String, CaseIterable, Codable, Sendable {
    case breath, blink, gazeX, gazeY, mouthOpen, mouthSmile, browRaise
    case headYaw, headPitch, headRoll, energy, warmth, attention

    var range: ClosedRange<Double> {
        switch self {
        case .breath, .blink, .mouthOpen, .energy, .warmth, .attention: return 0...1
        case .gazeX, .gazeY, .mouthSmile, .browRaise, .headYaw, .headPitch, .headRoll: return -1...1
        }
    }

    func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return PresenceChannels.neutral[keyPath: keyPath] }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    /// Seconds for the smoothed value to cover ~63% of the distance to a new target.
    var defaultEase: Double {
        switch self {
        case .mouthOpen: return 0.045
        case .blink: return 0.02
        case .gazeX, .gazeY: return 0.09
        case .headYaw, .headPitch, .headRoll: return 0.35
        case .energy, .warmth, .attention: return 0.8
        case .breath, .mouthSmile, .browRaise: return 0.25
        }
    }

    var keyPath: WritableKeyPath<PresenceChannels, Double> {
        switch self {
        case .breath: return \.breath
        case .blink: return \.blink
        case .gazeX: return \.gazeX
        case .gazeY: return \.gazeY
        case .mouthOpen: return \.mouthOpen
        case .mouthSmile: return \.mouthSmile
        case .browRaise: return \.browRaise
        case .headYaw: return \.headYaw
        case .headPitch: return \.headPitch
        case .headRoll: return \.headRoll
        case .energy: return \.energy
        case .warmth: return \.warmth
        case .attention: return \.attention
        }
    }
}

/// A partial update from the gateway. Unknown keys are ignored so the brain can
/// grow new channels before every body understands them.
struct ChannelPatch: Equatable, Sendable {
    var values: [ChannelKey: Double]
    /// Optional override for how quickly the body should move toward these targets.
    var ease: Double?

    init(values: [ChannelKey: Double], ease: Double? = nil) {
        self.values = values
        self.ease = ease
    }

    init(raw: [String: Double], ease: Double? = nil) {
        var mapped: [ChannelKey: Double] = [:]
        for (name, value) in raw {
            if let key = ChannelKey(rawValue: name) { mapped[key] = value }
        }
        self.init(values: mapped, ease: ease)
    }

    var raw: [String: Double] {
        Dictionary(uniqueKeysWithValues: values.map { ($0.key.rawValue, $0.value) })
    }
}
