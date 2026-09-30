import Foundation

/// In-process stand-in for the Windows gateway. It speaks the same contract as
/// `HTTPGateway`, streams slowly drifting continuous channels (her "inner weather")
/// and answers chat with an obviously-mock echo so no personality lives on device.
final class MockGateway: Gateway, @unchecked Sendable {
    private let lock = NSLock()
    private var activeBody: String?
    private let started = Date()
    private let streamHz: Double

    init(streamHz: Double = 15) {
        self.streamHz = streamHz
    }

    func health() async throws -> HealthResponse {
        HealthResponse(status: "ok", version: "mock-1")
    }

    func state() async throws -> GatewayState {
        GatewayState(
            activeBody: lock.withLock { activeBody },
            speaking: false,
            channels: MockGateway.weather(at: Date().timeIntervalSince(started)).raw,
            tokensVersion: DesignTokens.fallback.version
        )
    }

    func designTokens() async throws -> DesignTokens {
        .fallback
    }

    func claimPresence(_ request: PresenceClaimRequest) async throws -> PresenceLease {
        lock.withLock { activeBody = request.deviceId }
        return PresenceLease(granted: true, leaseSeconds: 15, activeBody: request.deviceId)
    }

    func heartbeat(_ request: PresenceHeartbeat) async throws -> PresenceLease {
        let body = lock.withLock { activeBody }
        return PresenceLease(granted: body == request.deviceId, leaseSeconds: 15, activeBody: body)
    }

    func sendPerception(_ batch: PerceptionBatch) async throws {}

    func stream() -> AsyncThrowingStream<StreamEvent, Error> {
        let started = self.started
        let interval = UInt64(1_000_000_000 / streamHz)
        return AsyncThrowingStream { continuation in
            let task = Task {
                continuation.yield(.presence(activeBody: self.lock.withLock { self.activeBody }))
                while !Task.isCancelled {
                    let t = Date().timeIntervalSince(started)
                    continuation.yield(.channels(MockGateway.weather(at: t)))
                    try? await Task.sleep(nanoseconds: interval)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func chat(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        let reply = "（Mock 网关）收到：「\(request.message)」。接入 Windows 网关后，这里会是可可真正的回答。"
        return AsyncThrowingStream { continuation in
            let task = Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                continuation.yield(.channels(ChannelPatch(values: [.attention: 0.9, .browRaise: 0.25], ease: 0.3)))
                var rng = SplitMix64(seed: UInt64(request.message.count) &+ 7)
                for ch in reply {
                    if Task.isCancelled { break }
                    let pause = "，。！？、「」（）".contains(ch)
                    let open = pause ? 0.0 : Double.random(in: 0.35...0.9, using: &rng)
                    continuation.yield(.channels(ChannelPatch(values: [.mouthOpen: open], ease: 0.035)))
                    continuation.yield(.delta(String(ch)))
                    try? await Task.sleep(nanoseconds: pause ? 180_000_000 : 55_000_000)
                }
                continuation.yield(.channels(ChannelPatch(values: [.mouthOpen: 0, .browRaise: 0], ease: 0.08)))
                continuation.yield(.done)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Slow, continuous drift of mood-like channels. Pure function of time so it is
    /// testable and identical across reconnects.
    static func weather(at t: Double) -> ChannelPatch {
        func wave(_ f: Double, _ p: Double) -> Double { sin(t * f + p) }
        let energy = 0.5 + 0.25 * wave(0.05, 0) + 0.1 * wave(0.13, 1.7)
        let warmth = 0.6 + 0.25 * wave(0.031, 2.1)
        let attention = 0.55 + 0.35 * wave(0.07, 0.4)
        // Occasionally glance aside, then come back to the viewer.
        let glance = max(0, wave(0.045, 3.0) - 0.6) / 0.4
        return ChannelPatch(values: [
            .energy: energy,
            .warmth: warmth,
            .attention: attention * (1 - 0.6 * glance),
            .mouthSmile: 0.1 + 0.35 * warmth * (0.7 + 0.3 * wave(0.11, 0.9)),
            .browRaise: 0.15 * wave(0.09, 2.4),
            .gazeX: 0.55 * glance * (wave(0.021, 0.2) >= 0 ? 1 : -1),
            .gazeY: 0.1 * wave(0.06, 1.1),
            .headYaw: 0.18 * glance * (wave(0.021, 0.2) >= 0 ? 1 : -1),
            .headRoll: 0.08 * wave(0.04, 0.5),
        ])
    }
}
