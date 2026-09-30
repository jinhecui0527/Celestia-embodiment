import Foundation

/// Talks to the Windows gateway over HTTP, SSE and WebSocket.
final class HTTPGateway: Gateway, @unchecked Sendable {
    let config: GatewayConfig
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(config: GatewayConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func health() async throws -> HealthResponse {
        try await get("/v1/health")
    }

    func state() async throws -> GatewayState {
        try await get("/v1/state")
    }

    func designTokens() async throws -> DesignTokens {
        try await get("/v1/design-tokens")
    }

    func claimPresence(_ request: PresenceClaimRequest) async throws -> PresenceLease {
        try await post("/v1/presence/claim", request)
    }

    func heartbeat(_ request: PresenceHeartbeat) async throws -> PresenceLease {
        try await post("/v1/presence/heartbeat", request)
    }

    func sendPerception(_ batch: PerceptionBatch) async throws {
        let request = config.request("/v1/perception", method: "POST", body: try encoder.encode(batch))
        let (_, response) = try await session.data(for: request)
        try check(response, path: "/v1/perception")
    }

    func stream() -> AsyncThrowingStream<StreamEvent, Error> {
        let config = self.config
        let session = self.session
        return AsyncThrowingStream { continuation in
            guard let url = config.streamURL else {
                continuation.finish(throwing: GatewayError.invalidURL)
                return
            }
            var request = URLRequest(url: url)
            for (name, value) in config.headers { request.setValue(value, forHTTPHeaderField: name) }
            let socket = session.webSocketTask(with: request)
            socket.resume()

            let task = Task {
                do {
                    while !Task.isCancelled {
                        let message = try await socket.receive()
                        let data: Data
                        switch message {
                        case let .string(text): data = Data(text.utf8)
                        case let .data(bytes): data = bytes
                        @unknown default: continue
                        }
                        if let event = try? StreamEvent.decode(data) {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                socket.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    func chat(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        let config = self.config
        let session = self.session
        let body = try? encoder.encode(request)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var urlRequest = config.request("/v1/chat", method: "POST", body: body, accept: "text/event-stream")
                    urlRequest.timeoutInterval = 120
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    try self.check(response, path: "/v1/chat")

                    var parser = SSEParser()
                    for try await line in bytes.lines {
                        // `lines` drops empty lines, so treat each data line as its own
                        // message boundary by flushing after it.
                        _ = parser.feed(line: line)
                        if line.hasPrefix("data:"), let message = parser.feed(line: "") {
                            if let event = ChatEvent.from(message) {
                                continuation.yield(event)
                                if event == .done { break }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let (data, response) = try await session.data(for: config.request(path))
        try check(response, path: path)
        return try decoder.decode(T.self, from: data)
    }

    private func post<Body: Encodable, T: Decodable>(_ path: String, _ body: Body) async throws -> T {
        let request = config.request(path, method: "POST", body: try encoder.encode(body))
        let (data, response) = try await session.data(for: request)
        try check(response, path: path)
        return try decoder.decode(T.self, from: data)
    }

    private func check(_ response: URLResponse, path: String) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 401 { throw GatewayError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw GatewayError.http(status: http.statusCode, path: path)
        }
    }
}
