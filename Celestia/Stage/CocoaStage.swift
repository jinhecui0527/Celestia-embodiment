import SwiftUI

enum StagePanel: String, Identifiable {
    case chat, link, perception, body
    var id: String { rawValue }
}

/// The whole screen. Cocoa is always center and full-size; every control is glass
/// that floats around her and never hides her face.
struct CocoaStage: View {
    @EnvironmentObject private var presence: PresenceEngine
    @EnvironmentObject private var link: LinkController
    @Environment(\.theme) private var theme

    @State private var panel: StagePanel?
    @State private var showHome = false
    @State private var pack = AvatarPack()

    private let homeItems = [
        HoneycombItem(id: StagePanel.chat.rawValue, title: "对话", systemImage: "bubble.left.and.text.bubble.right"),
        HoneycombItem(id: StagePanel.link.rawValue, title: "连接", systemImage: "point.3.connected.trianglepath.dotted"),
        HoneycombItem(id: StagePanel.perception.rawValue, title: "感知", systemImage: "hand.point.up.left"),
        HoneycombItem(id: StagePanel.body.rawValue, title: "身体", systemImage: "waveform.path.ecg"),
    ]

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width > proxy.size.height
            ZStack {
                StageBackground()

                CocoaAvatarView(engine: presence, pack: pack, accent: theme.accent) { focus in
                    link.report(PerceptionEvent(kind: "touch", values: ["x": Double(focus.x), "y": Double(focus.y)]))
                }
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    HStack {
                        StatusPill(text: link.status.label, color: statusColor)
                        Spacer()
                    }
                    Spacer()
                    if panel != .chat { Subtitle(line: latestCocoaLine) }
                    ornament
                }
                .padding(24)

                if showHome { home }

                if let panel {
                    panelView(panel)
                        .frame(width: wide ? min(420, proxy.size.width * 0.38) : min(560, proxy.size.width - 48))
                        .frame(maxHeight: wide ? proxy.size.height - 140 : proxy.size.height * 0.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: wide ? .trailing : .bottom)
                        .padding(.trailing, wide ? 24 : 0)
                        .padding(.bottom, wide ? 0 : 104)
                        .transition(.move(edge: wide ? .trailing : .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.86), value: panel)
            .animation(.easeOut(duration: 0.25), value: showHome)
        }
    }

    private var ornament: some View {
        Ornament {
            OrnamentButton(systemImage: "circle.hexagongrid", label: "主页", isActive: showHome) {
                showHome.toggle()
            }
            OrnamentButton(systemImage: "bubble.left", label: "对话", isActive: panel == .chat) { toggle(.chat) }
            OrnamentButton(systemImage: "gearshape", label: "连接设置", isActive: panel == .link) { toggle(.link) }
        }
    }

    private var home: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { showHome = false }
            AppHoneycomb(items: homeItems, columns: 2) { item in
                showHome = false
                panel = StagePanel(rawValue: item.id)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    @ViewBuilder
    private func panelView(_ panel: StagePanel) -> some View {
        let close = { self.panel = nil }
        switch panel {
        case .chat: ChatPanel(onClose: close)
        case .link: LinkPanel(onClose: close)
        case .perception: PerceptionPanel(onClose: close)
        case .body: BodyPanel(pack: pack, onClose: close)
        }
    }

    private func toggle(_ target: StagePanel) {
        showHome = false
        panel = panel == target ? nil : target
    }

    private var latestCocoaLine: String? {
        guard let last = link.transcript.last(where: { $0.role == .cocoa }), !last.text.isEmpty else { return nil }
        return last.text
    }

    private var statusColor: Color {
        switch link.status {
        case .embodied: return .green
        case .standby: return .yellow
        case .connecting, .idle: return .gray
        case .offline: return .red
        }
    }
}

private struct StageBackground: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            LinearGradient(colors: [theme.stageTop, theme.stageBottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [theme.accent.opacity(0.10), .clear], center: .init(x: 0.5, y: 1.1),
                           startRadius: 10, endRadius: 700)
        }
        .ignoresSafeArea()
    }
}

/// Her latest words, shown as a caption instead of a chat bubble over her face.
private struct Subtitle: View {
    let line: String?

    var body: some View {
        if let line {
            Text(line)
                .font(.title3)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(GlassSurface(shape: RoundedRectangle(cornerRadius: 22, style: .continuous)))
                .frame(maxWidth: 640)
                .transition(.opacity)
        }
    }
}
