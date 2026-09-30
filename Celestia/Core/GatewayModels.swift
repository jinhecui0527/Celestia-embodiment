import Foundation

enum DeviceType: String, Codable, CaseIterable, Sendable {
    case tablet
    case ipad
}

struct HealthResponse: Codable, Equatable, Sendable {
    var status: String
    var version: String?
}

/// Snapshot from `GET /v1/state`. Memory, schedule and personality stay on the
/// gateway; the body only needs to know who is embodied and where the channels are.
struct GatewayState: Codable, Equatable, Sendable {
    var activeBody: String?
    var speaking: Bool?
    var channels: [String: Double]?
    var tokensVersion: String?
}

struct PresenceClaimRequest: Codable, Equatable, Sendable {
    var deviceId: String
    var deviceType: DeviceType
    var capabilities: [String]
}

struct PresenceHeartbeat: Codable, Equatable, Sendable {
    var deviceId: String
    var focused: Bool
}

struct PresenceLease: Codable, Equatable, Sendable {
    var granted: Bool
    var leaseSeconds: Double
    var activeBody: String?
}

struct PerceptionEvent: Codable, Equatable, Sendable {
    var kind: String
    var at: Double
    var values: [String: Double]

    init(kind: String, at: Date = Date(), values: [String: Double] = [:]) {
        self.kind = kind
        self.at = at.timeIntervalSince1970
        self.values = values
    }
}

struct PerceptionBatch: Codable, Equatable, Sendable {
    var deviceId: String
    var events: [PerceptionEvent]
}

struct ChatRequest: Codable, Equatable, Sendable {
    var message: String
    var deviceId: String
}

/// Visual tokens served by the gateway so every body of Cocoa shares one look.
struct DesignTokens: Codable, Equatable, Sendable {
    var version: String
    var accent: String
    var stageTop: String
    var stageBottom: String
    var glassFill: Double
    var glassStroke: Double
    var cornerRadius: Double

    static let fallback = DesignTokens(
        version: "local-1",
        accent: "#F2B880",
        stageTop: "#1A1420",
        stageBottom: "#07060A",
        glassFill: 0.07,
        glassStroke: 0.28,
        cornerRadius: 30
    )
}

enum StreamEvent: Equatable, Sendable {
    case channels(ChannelPatch)
    case presence(activeBody: String?)
    case tokens(DesignTokens)
    case ping

    private struct Envelope: Decodable {
        var type: String
        var values: [String: Double]?
        var ease: Double?
        var activeBody: String?
        var tokens: DesignTokens?
    }

    /// Decodes one `/v1/stream` frame. Returns nil for unknown types so newer
    /// gateways can add events without breaking older bodies.
    static func decode(_ data: Data) throws -> StreamEvent? {
        let env = try JSONDecoder().decode(Envelope.self, from: data)
        switch env.type {
        case "channels": return .channels(ChannelPatch(raw: env.values ?? [:], ease: env.ease))
        case "presence": return .presence(activeBody: env.activeBody)
        case "tokens": return env.tokens.map(StreamEvent.tokens)
        case "ping": return .ping
        default: return nil
        }
    }
}

enum ChatEvent: Equatable, Sendable {
    case delta(String)
    case channels(ChannelPatch)
    case done
    case failure(String)

    private struct Payload: Decodable {
        var text: String?
        var values: [String: Double]?
        var ease: Double?
        var message: String?
    }

    static func from(_ message: SSEMessage) -> ChatEvent? {
        let payload = try? JSONDecoder().decode(Payload.self, from: Data(message.data.utf8))
        switch message.event {
        case "delta", "message":
            return (payload?.text).map(ChatEvent.delta) ?? .delta(message.data)
        case "channels":
            return payload?.values.map { .channels(ChannelPatch(raw: $0, ease: payload?.ease)) }
        case "done":
            return .done
        case "error":
            return .failure(payload?.message ?? message.data)
        default:
            return nil
        }
    }
}
