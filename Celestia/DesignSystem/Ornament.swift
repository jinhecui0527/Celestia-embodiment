import SwiftUI

/// A capsule of glass controls that hangs off the stage or a window edge, like a
/// visionOS ornament.
struct Ornament<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 6) { content }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .foregroundStyle(.white)
            .background(GlassSurface(shape: Capsule()))
    }
}

struct OrnamentButton: View {
    let systemImage: String
    let label: String
    var isActive = false
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(Circle().fill(isActive ? theme.accent.opacity(0.35) : .white.opacity(0.001)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Small status pill: a colored dot plus text.
struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
                .shadow(color: color, radius: 4)
            Text(text).font(.footnote.weight(.medium)).lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .foregroundStyle(.white)
        .background(GlassSurface(shape: Capsule()))
    }
}
