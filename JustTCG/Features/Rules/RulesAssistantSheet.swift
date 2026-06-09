import SwiftUI

struct RulesAssistantSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [RulesMessage] = []
    @State private var draft = ""
    @State private var isGenerating = false

    private let fallback = RulesQueryEngineFallback()

    // Stored as Any so the @available guard works without needing to make the whole view @available
    @State private var engineBox: AnyObject? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                Divider()
                inputBar
            }
            .navigationTitle("Rules Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !messages.isEmpty {
                        Button("Clear") { clearConversation() }
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task {
            if #available(iOS 26, *), engineBox == nil {
                engineBox = RulesQueryEngine()
            }
        }
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    emptyPrompt
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }
                        if isGenerating {
                            HStack {
                                ProgressView()
                                    .padding(10)
                                    .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 14))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .onChange(of: messages.count) {
                withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            }
            .onChange(of: isGenerating) {
                withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ msg: RulesMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 60) }
            Text(msg.text)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    msg.role == .user ? Color.accentColor : Color(.secondarySystemFill),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .foregroundStyle(msg.role == .user ? .white : .primary)
            if msg.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
    }

    private var emptyPrompt: some View {
        Text("Ask anything about Pokémon TCG rules — setup, attacking, special conditions, prizes, and more.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask a rules question…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .disabled(isGenerating)
            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func send() {
        let q = draft.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        messages.append(RulesMessage(role: .user, text: q))
        draft = ""
        isGenerating = true

        Task {
            do {
                let answer: String
                if #available(iOS 26, *), let engine = engineBox as? RulesQueryEngine {
                    answer = try await engine.ask(q)
                } else {
                    answer = await fallback.ask(q)
                }
                messages.append(RulesMessage(role: .assistant, text: answer))
            } catch {
                messages.append(RulesMessage(role: .assistant, text: "Something went wrong. Please try again."))
            }
            isGenerating = false
        }
    }

    private func clearConversation() {
        messages.removeAll()
        if #available(iOS 26, *), let engine = engineBox as? RulesQueryEngine {
            engine.reset()
        }
    }
}

// MARK: - Message model

private struct RulesMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String
    enum Role { case user, assistant }
}
