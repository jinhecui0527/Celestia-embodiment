import Combine
import Foundation

enum LinkStatus: Equatable {
    case idle
    case connecting
    /// This iPad holds Cocoa's presence lease.
    case embodied
    /// Another body (PC, phone…) holds presence; she idles here at low attention.
    case standby(activeBody: String?)
    case offline(String)

    var label: String {
        switch self {
        case .idle: return "未连接"
        case .connecting: return "正在连接…"
        case .embodied: return "可可在这里"
        case let .standby(body): return body.map { "可可在 \($0) 上" } ?? "可可在别处"
        case let .offline(reason): return reason
        }
    }

    var isLive: Bool {
        switch self {
        case .embodied, .standby: return true
        default: return false
        }
    }
}

struct ChatLine: Identifiable, Equatable {
    enum Role { case user, cocoa, system }
    let id = UUID()
    let role: Role
    var text: String
}

/// Owns the session with the gateway: health → tokens → presence claim, then runs
/// heartbeat, `/v1/stream` and perception upload concurrently, reconnecting with
/// backoff. Stream channel patches are fed straight into the presence engine.
@MainActor
final class LinkController: ObservableObject {
    @Published private(set) var status: LinkStatus = .idle
    @Published private(set) var tokens: DesignTokens = .fallback
    @Published private(set) var transcript: [ChatLine] = []
    @Published private(set) var isReplying = false
    @Published private(set) var gatewayVersion: String?

    let settings: LinkSettings
    let presence: PresenceEngine

    private var gateway: Gateway?
    private var sessionTask: Task<Void, Never>?
    private var chatTask: Task<Void, Never>?
    private var perceptionBuffer: [PerceptionEvent] = []
    private var isForeground = true

    init(settings: LinkSettings, presence: PresenceEngine) {
        self.settings = settings
        self.presence = presence
    }

    func restart() {
        sessionTask?.cancel()
        chatTask?.cancel()
        isReplying = false
        gatewayVersion = nil
        status = .connecting

        let gateway: Gateway
        switch settings.mode {
        case .mock:
            gateway = MockGateway()
        case .live:
            do {
                gateway = HTTPGateway(config: try settings.gatewayConfig())
            } catch {
                self.gateway = nil
                status = .offline(Self.describe(error))
                return
            }
        }
        self.gateway = gateway
        sessionTask = Task { [weak self] in await self?.runSession(gateway) }
    }

    func setForeground(_ foreground: Bool) {
        isForeground = foreground
        report(PerceptionEvent(kind: "focus", values: ["foreground": foreground ? 1 : 0]))
    }

    func report(_ event: PerceptionEvent) {
        guard settings.sharePerception else { return }
        perceptionBuffer.append(event)
        if perceptionBuffer.count > 64 { perceptionBuffer.removeFirst(perceptionBuffer.count - 64) }
    }

    func send(_ message: String) {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        transcript.append(ChatLine(role: .user, text: text))
        guard let gateway else {
            transcript.append(ChatLine(role: .system, text: "还没有连上网关。"))
            return
        }

        chatTask?.cancel()
        transcript.append(ChatLine(role: .cocoa, text: ""))
        let index = transcript.count - 1
        isReplying = true
        let request = ChatRequest(message: text, deviceId: settings.deviceId)

        chatTask = Task { [weak self] in
            do {
                for try await event in gateway.chat(request) {
                    guard let self else { return }
                    switch event {
                    case let .delta(chunk):
                        if self.transcript.indices.contains(index) { self.transcript[index].text += chunk }
                    case let .channels(patch): self.presence.apply(patch)
                    case .done: break
                    case let .failure(message): self.transcript.append(ChatLine(role: .system, text: message))
                    }
                }
            } catch is CancellationError {
            } catch {
                self?.transcript.append(ChatLine(role: .system, text: Self.describe(error)))
            }
            guard let self else { return }
            if self.transcript.indices.contains(index), self.transcript[index].text.isEmpty {
                self.transcript.remove(at: index)
            }
            self.presence.apply(ChannelPatch(values: [.mouthOpen: 0], ease: 0.08))
            self.isReplying = false
        }
    }

    private func runSession(_ gateway: Gateway) async {
        var backoff: Double = 1
        while !Task.isCancelled {
            do {
                status = .connecting
                gatewayVersion = try await gateway.health().version
                if let tokens = try? await gateway.designTokens() { self.tokens = tokens }
                if let raw = try? await gateway.state().channels { presence.apply(ChannelPatch(raw: raw)) }

                let lease = try await gateway.claimPresence(PresenceClaimRequest(
                    deviceId: settings.deviceId,
                    deviceType: settings.deviceType,
                    capabilities: ["presence.layered2d", "perception.touch", "perception.motion", "chat.sse"]
                ))
                apply(lease)
                backoff = 1

                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask { try await self.heartbeatLoop(gateway, every: lease.leaseSeconds / 3) }
                    group.addTask { try await self.streamLoop(gateway) }
                    group.addTask { try await self.perceptionLoop(gateway) }
                    _ = try await group.next()
                    group.cancelAll()
                }
                if !Task.isCancelled { status = .offline("连接已断开，正在重连…") }
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                status = .offline(Self.describe(error))
            }
            try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            backoff = min(backoff * 2, 30)
        }
    }

    private func heartbeatLoop(_ gateway: Gateway, every interval: Double) async throws {
        let seconds = min(max(interval, 2), 30)
        while !Task.isCancelled {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            let lease = try await gateway.heartbeat(PresenceHeartbeat(deviceId: settings.deviceId, focused: isForeground))
            apply(lease)
        }
    }

    private func streamLoop(_ gateway: Gateway) async throws {
        for try await event in gateway.stream() {
            switch event {
            case let .channels(patch): presence.apply(patch)
            case let .presence(activeBody): applyActiveBody(activeBody)
            case let .tokens(tokens): self.tokens = tokens
            case .ping: break
            }
        }
    }

    private func perceptionLoop(_ gateway: Gateway) async throws {
        while !Task.isCancelled {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            guard !perceptionBuffer.isEmpty else { continue }
            let batch = PerceptionBatch(deviceId: settings.deviceId, events: perceptionBuffer)
            perceptionBuffer.removeAll()
            try? await gateway.sendPerception(batch)
        }
    }

    private func apply(_ lease: PresenceLease) {
        if lease.granted {
            applyActiveBody(settings.deviceId)
        } else {
            applyActiveBody(lease.activeBody)
        }
    }

    private func applyActiveBody(_ body: String?) {
        let embodied = body == settings.deviceId
        status = embodied ? .embodied : .standby(activeBody: body)
        presence.isDormant = !embodied
    }

    private static func describe(_ error: Error) -> String {
        if let gatewayError = error as? GatewayError, let text = gatewayError.errorDescription { return text }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost: return "找不到网关，请检查地址和局域网"
            case .timedOut: return "网关响应超时"
            case .notConnectedToInternet: return "iPad 没有联网"
            default: return urlError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
