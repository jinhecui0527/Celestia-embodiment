import SwiftUI

struct HoneycombItem: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
}

/// visionOS-home-style honeycomb: round glass icons in offset rows.
struct AppHoneycomb: View {
    let items: [HoneycombItem]
    var columns = 3
    let onSelect: (HoneycombItem) -> Void

    private let iconSize: CGFloat = 76
    private let spacing: CGFloat = 22

    var body: some View {
        VStack(spacing: spacing * 0.4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: spacing) {
                    ForEach(row) { item in
                        HoneycombCell(item: item, size: iconSize) { onSelect(item) }
                    }
                }
                .offset(x: index.isMultiple(of: 2) ? 0 : (iconSize + spacing) / 2)
            }
        }
        .padding(.trailing, rows.count > 1 ? (iconSize + spacing) / 2 : 0)
    }

    private var rows: [[HoneycombItem]] {
        stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
    }
}

private struct HoneycombCell: View {
    let item: HoneycombItem
    let size: CGFloat
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: item.systemImage)
                    .font(.system(size: size * 0.36, weight: .medium))
                    .frame(width: size, height: size)
                    .background(
                        ZStack {
                            GlassSurface(shape: Circle())
                            Circle().fill(RadialGradient(colors: [theme.accent.opacity(0.28), .clear],
                                                         center: .top, startRadius: 0, endRadius: size))
                        }
                    )
                Text(item.title).font(.footnote.weight(.medium))
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(HoneycombPressStyle())
    }
}

private struct HoneycombPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
