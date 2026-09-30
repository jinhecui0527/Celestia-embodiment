import SwiftUI

/// visionOS-style window glass without any blur: a faint tinted fill, a specular
/// top edge and a gradient rim. Content behind stays crisp, which keeps Cocoa
/// visible through every panel.
struct GlassSurface<S: InsettableShape>: View {
    let shape: S
    @Environment(\.theme) private var theme

    var body: some View {
        shape
            .fill(Color.white.opacity(theme.glassFill))
            .overlay(
                shape.fill(
                    LinearGradient(colors: [.white.opacity(theme.glassFill * 1.4), .clear],
                                   startPoint: .top, endPoint: .center)
                )
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(theme.glassStroke), .white.opacity(theme.glassStroke * 0.2),
                                            .white.opacity(theme.glassStroke * 0.5)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
            )
            .background(shape.fill(Color.black.opacity(0.35)))
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
    }
}

struct GlassWindow<Content: View>: View {
    var title: String?
    var onClose: (() -> Void)?
    @ViewBuilder var content: Content
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if title != nil || onClose != nil {
                HStack {
                    if let title {
                        Text(title).font(.title3.weight(.semibold))
                    }
                    Spacer()
                    if let onClose {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.footnote.weight(.bold))
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("关闭")
                    }
                }
            }
            content
        }
        .padding(24)
        .foregroundStyle(.white)
        .background(GlassSurface(shape: RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)))
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.purple, .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        GlassWindow(title: "连接", onClose: {}) {
            Text("Glass without blur").foregroundStyle(.secondary)
        }
        .frame(width: 360)
    }
}
