import SwiftUI

struct ChatPanel: View {
    let onClose: () -> Void
    @EnvironmentObject private var link: LinkController
    @Environment(\.theme) private var theme
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        GlassWindow(title: "对话", onClose: onClose) {
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if link.transcript.isEmpty {
                            Text(emptyHint)
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 24)
                        }
                        ForEach(link.transcript) { line in
                            ChatRow(line: line).id(line.id)
                        }
                        if link.isReplying && (link.transcript.last?.text.isEmpty ?? true) {
                            ProgressView().tint(.white).padding(.leading, 6)
                        }
                    }
                }
                .frame(minHeight: 160)
                .onChange(of: link.transcript) { _, lines in
                    if let last = lines.last { withAnimation { reader.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            HStack(spacing: 10) {
                TextField("和可可说点什么", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white.opacity(0.08)))
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(canSend ? theme.accent : .white.opacity(0.12)))
                        .foregroundStyle(canSend ? .black : .white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("发送")
            }
        }
        .onAppear { focused = true }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !link.isReplying
    }

    private var emptyHint: String {
        link.settings.mode == .mock
            ? "当前是 Mock 网关：回复只是回声，用来验证口型和字幕链路。"
            : "消息会发送到 Windows 网关，由那边的可可回答。"
    }

    private func send() {
        guard canSend else { return }
        link.send(draft)
        draft = ""
    }
}

private struct ChatRow: View {
    let line: ChatLine

    var body: some View {
        HStack {
            if line.role == .user { Spacer(minLength: 40) }
            Text(line.text)
                .font(line.role == .system ? .footnote : .body)
                .foregroundStyle(line.role == .system ? .orange : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(line.role == .user ? 0.16 : 0.06))
                )
                .textSelection(.enabled)
            if line.role != .user { Spacer(minLength: 40) }
        }
    }
}
