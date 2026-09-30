import SwiftUI

/// What this body senses and what it shares with the gateway.
struct PerceptionPanel: View {
    let onClose: () -> Void
    @EnvironmentObject private var settings: LinkSettings
    @EnvironmentObject private var presence: PresenceEngine

    var body: some View {
        GlassWindow(title: "感知", onClose: onClose) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("上报感知到网关 (POST /v1/perception)", isOn: $settings.sharePerception)
                    .tint(.green)
                sense("hand.point.up.left", "触摸", "她会看向你的手指；触摸位置会上报。")
                sense("iphone.gen3.radiowaves.left.and.right", "设备姿态",
                      presence.motion.isAvailable ? "驱动分层视差，只在本机使用。" : "此设备没有陀螺仪（模拟器），视差仅来自触摸。")
                sense("app.badge", "前台状态", "切到后台时心跳会标记 focused=false。")
                sense("camera", "摄像头 / 麦克风", "Phase A 未启用，接口已在契约中预留。")
                    .opacity(0.5)
            }
            .font(.callout)
        }
    }

    private func sense(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(detail).font(.footnote).foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

/// Live view of the continuous channels driving her right now.
struct BodyPanel: View {
    let pack: AvatarPack
    let onClose: () -> Void
    @EnvironmentObject private var presence: PresenceEngine
    @Environment(\.theme) private var theme

    var body: some View {
        GlassWindow(title: "身体", onClose: onClose) {
            VStack(alignment: .leading, spacing: 12) {
                Text(pack.isVectorFallback ? "渲染：2D 分层矢量（未导入美术包）" : "渲染：2D 分层美术包「\(pack.name)」")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.65))
                TimelineView(.periodic(from: .now, by: 1.0 / 15)) { _ in
                    let c = presence.current
                    VStack(spacing: 8) {
                        ForEach(ChannelKey.allCases, id: \.self) { key in
                            ChannelBar(name: key.rawValue, value: c[key], range: key.range, color: theme.accent)
                        }
                    }
                }
            }
        }
    }
}

private struct ChannelBar: View {
    let name: String
    let value: Double
    let range: ClosedRange<Double>
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(name).font(.caption.monospaced()).frame(width: 92, alignment: .leading)
            GeometryReader { proxy in
                let span = range.upperBound - range.lowerBound
                let t = (value - range.lowerBound) / span
                let zero = (0 - range.lowerBound) / span
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule().fill(color)
                        .frame(width: max(3, abs(t - zero) * proxy.size.width))
                        .offset(x: min(t, zero) * proxy.size.width)
                }
            }
            .frame(height: 6)
            Text(String(format: "%+.2f", value)).font(.caption2.monospaced()).frame(width: 44, alignment: .trailing)
        }
        .foregroundStyle(.white.opacity(0.85))
    }
}
