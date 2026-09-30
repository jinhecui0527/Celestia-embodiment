import XCTest
@testable import CelestiaCore

final class ChannelTests: XCTestCase {
    func testPatchIgnoresUnknownKeysAndClampsOnApply() {
        let patch = ChannelPatch(raw: ["mouthOpen": 3, "futureChannel": 1, "gazeX": -4])
        XCTAssertEqual(patch.values.count, 2)

        var channels = PresenceChannels.neutral
        for (key, value) in patch.values { channels[key] = value }
        XCTAssertEqual(channels.mouthOpen, 1)
        XCTAssertEqual(channels.gazeX, -1)
    }

    func testNonFiniteValuesFallBackToNeutral() {
        var channels = PresenceChannels.neutral
        channels[.warmth] = .nan
        XCTAssertEqual(channels.warmth, PresenceChannels.neutral.warmth)
    }
}

final class LocalLifeTests: XCTestCase {
    func testBreathStaysInRangeAndCycles() {
        var life = LocalLife(seed: 1)
        var minB = 1.0, maxB = 0.0
        for _ in 0..<(60 * 12) {
            let out = life.advance(dt: 1.0 / 60, energy: 0.5)
            minB = min(minB, out.breath)
            maxB = max(maxB, out.breath)
        }
        XCTAssertLessThan(minB, 0.05)
        XCTAssertGreaterThan(maxB, 0.95)
    }

    func testBlinksHappenAndFullyClose() {
        var life = LocalLife(seed: 42)
        var closures = 0
        var wasClosed = false
        for _ in 0..<(60 * 30) {
            let closed = life.advance(dt: 1.0 / 60, energy: 0.5).blink > 0.95
            if closed && !wasClosed { closures += 1 }
            wasClosed = closed
        }
        XCTAssertGreaterThanOrEqual(closures, 4, "expected a natural blink rate over 30s")
        XCTAssertLessThanOrEqual(closures, 25)
    }

    func testDeterministicForSeed() {
        var a = LocalLife(seed: 9), b = LocalLife(seed: 9)
        for _ in 0..<300 {
            XCTAssertEqual(a.advance(dt: 1.0 / 60, energy: 0.3), b.advance(dt: 1.0 / 60, energy: 0.3))
        }
    }
}

final class ChannelMixerTests: XCTestCase {
    func testMovesTowardGatewayTargetSmoothly() {
        var mixer = ChannelMixer(seed: 3)
        mixer.apply(ChannelPatch(values: [.mouthOpen: 1]))
        let first = mixer.advance(dt: 1.0 / 60).mouthOpen
        XCTAssertGreaterThan(first, 0)
        XCTAssertLessThan(first, 1, "should ease, not jump")
        var last = first
        for _ in 0..<30 { last = mixer.advance(dt: 1.0 / 60).mouthOpen }
        XCTAssertGreaterThan(last, 0.95)
    }

    func testRelaxesWhenGatewayGoesSilent() {
        var mixer = ChannelMixer(seed: 3)
        mixer.apply(ChannelPatch(values: [.mouthOpen: 1, .warmth: 1]))
        for _ in 0..<(60 * 6) { _ = mixer.advance(dt: 1.0 / 60) }
        XCTAssertLessThan(mixer.smoothed.mouthOpen, 0.05)
        XCTAssertEqual(mixer.smoothed.warmth, PresenceChannels.neutral.warmth, accuracy: 0.05)
    }

    func testViewerFocusPullsGaze() {
        var mixer = ChannelMixer(seed: 5)
        mixer.apply(ChannelPatch(values: [.attention: 1]))
        mixer.viewerFocus = (x: 0.8, y: 0)
        var out = PresenceChannels.neutral
        for _ in 0..<120 { out = mixer.advance(dt: 1.0 / 60) }
        XCTAssertGreaterThan(out.gazeX, 0.5)
        XCTAssertGreaterThan(out.headYaw, 0.05)
    }
}

final class SSEParserTests: XCTestCase {
    func testParsesEventsDataAndComments() {
        var parser = SSEParser()
        let lines = [": keep-alive", "event: delta", "data: {\"text\":\"你\"}", "", "data: a", "data: b", "", "event: done", "data: {}"]
        var messages: [SSEMessage] = []
        for line in lines { if let m = parser.feed(line: line) { messages.append(m) } }
        if let m = parser.finish() { messages.append(m) }

        XCTAssertEqual(messages.map(\.event), ["delta", "message", "done"])
        XCTAssertEqual(messages[1].data, "a\nb")
        XCTAssertEqual(ChatEvent.from(messages[0]), .delta("你"))
        XCTAssertEqual(ChatEvent.from(messages[2]), .done)
    }

    func testChannelsEventInChat() {
        let event = ChatEvent.from(SSEMessage(event: "channels", data: "{\"values\":{\"mouthOpen\":0.5},\"ease\":0.04}"))
        XCTAssertEqual(event, .channels(ChannelPatch(values: [.mouthOpen: 0.5], ease: 0.04)))
    }
}

final class GatewayContractTests: XCTestCase {
    private let config = GatewayConfig(
        baseURL: URL(string: "http://192.168.1.20:8787")!,
        token: "secret",
        deviceId: "ipad-1",
        deviceType: .tablet
    )

    func testHeadersMatchContract() {
        let request = config.request("/v1/health")
        XCTAssertEqual(request.url?.absoluteString, "http://192.168.1.20:8787/v1/health")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Device-Id"), "ipad-1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Device-Type"), "tablet")
    }

    func testStreamURLUsesWebSocketScheme() {
        XCTAssertEqual(config.streamURL?.absoluteString, "ws://192.168.1.20:8787/v1/stream")
        var tls = config
        tls.baseURL = URL(string: "https://cocoa.example/gw")!
        XCTAssertEqual(tls.streamURL?.absoluteString, "wss://cocoa.example/gw/v1/stream")
    }

    func testDecodesStreamEvents() throws {
        let frame = Data(#"{"type":"channels","values":{"warmth":0.8,"nope":1},"ease":0.2}"#.utf8)
        XCTAssertEqual(try StreamEvent.decode(frame), .channels(ChannelPatch(values: [.warmth: 0.8], ease: 0.2)))
        XCTAssertNil(try StreamEvent.decode(Data(#"{"type":"future"}"#.utf8)))
        XCTAssertEqual(try StreamEvent.decode(Data(#"{"type":"presence","activeBody":"pc"}"#.utf8)), .presence(activeBody: "pc"))
    }
}

final class MockGatewayTests: XCTestCase {
    func testStreamDrivesChannels() async throws {
        let gateway = MockGateway(streamHz: 50)
        var patches = 0
        for try await event in gateway.stream() {
            if case let .channels(patch) = event {
                XCTAssertNotNil(patch.values[.energy])
                patches += 1
            }
            if patches == 3 { break }
        }
        XCTAssertEqual(patches, 3)
    }

    func testChatStreamsTextAndMouth() async throws {
        let gateway = MockGateway()
        var text = ""
        var sawMouth = false
        var done = false
        for try await event in gateway.chat(ChatRequest(message: "你好", deviceId: "d")) {
            switch event {
            case let .delta(s): text += s
            case let .channels(p): if (p.values[.mouthOpen] ?? 0) > 0 { sawMouth = true }
            case .done: done = true
            case .failure: XCTFail()
            }
        }
        XCTAssertTrue(text.contains("你好"))
        XCTAssertTrue(sawMouth)
        XCTAssertTrue(done)
    }

    func testPresenceClaimAndHeartbeat() async throws {
        let gateway = MockGateway()
        let lease = try await gateway.claimPresence(PresenceClaimRequest(deviceId: "a", deviceType: .ipad, capabilities: []))
        XCTAssertTrue(lease.granted)
        let other = try await gateway.heartbeat(PresenceHeartbeat(deviceId: "b", focused: true))
        XCTAssertFalse(other.granted)
        XCTAssertEqual(other.activeBody, "a")
    }
}
