import SwiftUI

/// The live avatar surface: samples the presence engine every display frame and
/// hands the channels to the layered renderer. Touch is local perception: she
/// looks toward your finger, and the touch is reported to the gateway.
struct CocoaAvatarView: View {
    @ObservedObject var engine: PresenceEngine
    let pack: AvatarPack
    let accent: Color
    var onTouch: (CGPoint) -> Void = { _ in }

    @State private var orientation: UIInterfaceOrientation = .portrait

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                let channels = engine.frame(at: timeline.date)
                let parallax = engine.motion.sample(orientation: orientation)
                let renderer = AvatarRenderer(pack: pack, accent: accent)
                let dormant = engine.isDormant
                Canvas { context, size in
                    renderer.draw(channels, parallax: parallax, dormant: dormant, in: &context, size: size)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let focus = normalized(value.location, in: proxy.size)
                        engine.setViewerFocus(focus)
                        if value.translation == .zero { onTouch(focus) }
                    }
                    .onEnded { _ in engine.setViewerFocus(nil) }
            )
            .onAppear { orientation = proxy.size.width > proxy.size.height ? .landscapeLeft : .portrait }
            .onChange(of: proxy.size) { _, size in
                orientation = currentOrientation(fallbackWide: size.width > size.height)
            }
        }
        .onAppear {
            orientation = currentOrientation(fallbackWide: false)
            engine.motion.start()
        }
        .onDisappear { engine.motion.stop() }
        .accessibilityElement()
        .accessibilityLabel("可可")
        .accessibilityHint("触摸屏幕，她会看向你的手指")
    }

    private func normalized(_ point: CGPoint, in size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return .zero }
        // The face sits at ~41% height; map so touching the face means "look at me".
        let x = (point.x / size.width - 0.5) * 2
        let y = -(point.y / size.height - 0.41) * 2
        return CGPoint(x: max(-1, min(1, x)), y: max(-1, min(1, y)))
    }

    private func currentOrientation(fallbackWide: Bool) -> UIInterfaceOrientation {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.interfaceOrientation ?? (fallbackWide ? .landscapeLeft : .portrait)
    }
}
