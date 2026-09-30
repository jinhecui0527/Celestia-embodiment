import SwiftUI

/// Gateway settings: mock/live switch, base URL, bearer token, device identity.
struct LinkPanel: View {
    let onClose: () -> Void
    @EnvironmentObject private var settings: LinkSettings
    @EnvironmentObject private var link: LinkController
    @Environment(\.theme) private var theme

    @State private var draftURL = ""
    @State private var draftToken = ""
    @State private var draftMode: LinkSettings.Mode = .mock
    @State private var draftType: DeviceType = .tablet

    var body: some View {
        GlassWindow(title: "连接", onClose: onClose) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("网关", selection: $draftMode) {
                        ForEach(LinkSettings.Mode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if draftMode == .live {
                        field("网关地址") {
                            TextField("http://192.168.1.10:8787", text: $draftURL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        field("Bearer 令牌") {
                            SecureField("存放在钥匙串中", text: $draftToken)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    } else {
                        Text("Mock 网关在 iPad 本地运行，按网关契约推送连续通道，不需要 Windows 端。")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.65))
                    }

                    field("设备类型 (X-Device-Type)") {
                        Picker("设备类型", selection: $draftType) {
                            ForEach(DeviceType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    field("设备 ID (X-Device-Id)") {
                        Text(settings.deviceId)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        StatusPill(text: link.status.label, color: link.status.isLive ? .green : .orange)
                        if let version = link.gatewayVersion {
                            Text("网关版本 \(version) · 设计令牌 \(link.tokens.version)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }

                    Button(action: apply) {
                        Text("保存并重新连接")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(theme.accent))
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            draftURL = settings.baseURL
            draftToken = settings.token
            draftMode = settings.mode
            draftType = settings.deviceType
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.6))
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.07)))
        }
    }

    private func apply() {
        settings.mode = draftMode
        settings.baseURL = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if settings.token != draftToken { settings.token = draftToken }
        settings.deviceType = draftType
        link.restart()
    }
}
