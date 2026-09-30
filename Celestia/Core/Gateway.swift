import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The body's side of the gateway contract. `HTTPGateway` talks to the real Windows
/// gateway; `MockGateway` runs in-process so the body can be developed alone.
protocol Gateway: AnyObject, Sendable {
    func health() async throws -> HealthResponse
    func state() async throws -> GatewayState
    func designTokens() async throws -> DesignTokens
    func claimPresence(_ request: PresenceClaimRequest) async throws -> PresenceLease
    func heartbeat(_ request: PresenceHeartbeat) async throws -> PresenceLease
    func sendPerception(_ batch: PerceptionBatch) async throws
    func stream() -> AsyncThrowingStream<StreamEvent, Error>
    func chat(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error>
}

struct GatewayConfig: Equatable, Sendable {
    var baseURL: URL
    var token: String
    var deviceId: String
    var deviceType: DeviceType

    var headers: [String: String] {
        var h = [
            "X-Device-Id": deviceId,
            "X-Device-Type": deviceType.rawValue,
        ]
        if !token.isEmpty { h["Authorization"] = "Bearer \(token)" }
        return h
    }

    func url(_ path: String) -> URL {
        baseURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
    }

    /// `http(s)://host/base` → `ws(s)://host/base/v1/stream`.
    var streamURL: URL? {
        guard var components = URLComponents(url: url("/v1/stream"), resolvingAgainstBaseURL: false) else {
            return nil
        }
        switch components.scheme?.lowercased() {
        case "https": components.scheme = "wss"
        case "http": components.scheme = "ws"
        default: break
        }
        return components.url
    }

    func request(_ path: String, method: String = "GET", body: Data? = nil, accept: String = "application/json") -> URLRequest {
        var request = URLRequest(url: url(path))
        request.httpMethod = method
        request.timeoutInterval = 10
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        request.setValue(accept, forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
}

enum GatewayError: LocalizedError, Equatable {
    case invalidURL
    case http(status: Int, path: String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "网关地址无效"
        case .unauthorized: return "令牌被网关拒绝（401）"
        case let .http(status, path): return "网关返回 \(status)：\(path)"
        }
    }
}
