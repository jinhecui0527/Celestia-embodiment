import Combine
import Foundation

/// User-editable link configuration. Everything except the token lives in
/// UserDefaults; the token lives in the Keychain.
final class LinkSettings: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case mock, live
        var id: String { rawValue }
        var label: String { self == .mock ? "Mock 网关" : "Windows 网关" }
    }

    private enum Key {
        static let mode = "link.mode"
        static let baseURL = "link.baseURL"
        static let deviceType = "link.deviceType"
        static let deviceId = "link.deviceId"
        static let sharePerception = "link.sharePerception"
        static let token = "bearer"
    }

    private let defaults: UserDefaults

    @Published var mode: Mode { didSet { defaults.set(mode.rawValue, forKey: Key.mode) } }
    @Published var baseURL: String { didSet { defaults.set(baseURL, forKey: Key.baseURL) } }
    @Published var deviceType: DeviceType { didSet { defaults.set(deviceType.rawValue, forKey: Key.deviceType) } }
    @Published var sharePerception: Bool { didSet { defaults.set(sharePerception, forKey: Key.sharePerception) } }
    @Published var token: String { didSet { KeychainStore.write(token, for: Key.token) } }
    let deviceId: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = Mode(rawValue: defaults.string(forKey: Key.mode) ?? "") ?? .mock
        baseURL = defaults.string(forKey: Key.baseURL) ?? "http://192.168.1.10:8787"
        deviceType = DeviceType(rawValue: defaults.string(forKey: Key.deviceType) ?? "") ?? .tablet
        sharePerception = defaults.object(forKey: Key.sharePerception) as? Bool ?? true
        token = KeychainStore.read(Key.token) ?? ""

        if let existing = defaults.string(forKey: Key.deviceId) {
            deviceId = existing
        } else {
            let fresh = "ipad-" + UUID().uuidString.prefix(8).lowercased()
            defaults.set(fresh, forKey: Key.deviceId)
            deviceId = fresh
        }
    }

    func gatewayConfig() throws -> GatewayConfig {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme), url.host != nil else {
            throw GatewayError.invalidURL
        }
        return GatewayConfig(baseURL: url, token: token, deviceId: deviceId, deviceType: deviceType)
    }
}
