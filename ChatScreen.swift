import SwiftUI

struct ChatScreen: View {
    let thread: ContentView.QuestionThread

    // Minimal local message model for UI
    struct ChatMessage: Identifiable {
        enum Role { case llm, user }
        let id = UUID()
        let role: Role
        let text: String
    }

    @State private var chat: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var nextLLMIndex: Int = 1
    @State private var isAnswered: Bool = false

    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(chat) { msg in
                            if msg.role == .llm {
                                llmText(msg.text)
                                    .id(msg.id)
                            } else {
                                userBubble(msg.text)
                                    .id(msg.id)
                            }
                        }

                        if isAnswered {
                            answeredBar
                                .padding(.top, 10)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                }
                .onTapGesture {
                    inputFocused = false
                }
                .onChange(of: chat.count) {
                    guard let last = chat.last else { return }
                    DispatchQueue.main.async {
                        withAnimation(.default) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input
            inputBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                header
            }
        }
        .onAppear {
            // Seed with the first LLM message (title)
            chat = [ChatMessage(role: .llm, text: thread.messages.first ?? "")]
            nextLLMIndex = 1
            isAnswered = false

            // Input focused by default
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                inputFocused = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            // Avatar placeholder
            Circle()
                .fill(Color(uiColor: .tertiarySystemFill))
                .frame(width: 28, height: 28)

            Badge(
                text: thread.llm,
                color: Badge.color(for: thread.llm),
                size: .big
            )

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - LLM text (no bubble)

    private func llmText(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - User bubble

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 246)

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .frame(maxWidth: 320, alignment: .trailing)
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 10) {
            Divider()

            HStack(spacing: 10) {
                TextField("Write an answer…", text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .focused($inputFocused)
                    .disabled(isAnswered)

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(isAnswered ? Color(uiColor: .tertiarySystemFill) : Color.accentColor)
                        .clipShape(Circle())
                }
                .disabled(isAnswered || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Answered bar

    private var answeredBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.bubble.fill")
                .foregroundColor(.green)
            Text("Question answered")
                .font(.headline)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Fake flow

    private func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isAnswered else { return }

        inputText = ""
        chat.append(ChatMessage(role: .user, text: trimmed))

        // Scripted follow-ups (user text doesn't matter)
        if nextLLMIndex < thread.messages.count {
            let next = thread.messages[nextLLMIndex]
            nextLLMIndex += 1

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                chat.append(ChatMessage(role: .llm, text: next))
            }
        } else {
            // No more follow-ups: mark as answered
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isAnswered = true
                inputFocused = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatScreen(
            thread: ContentView.QuestionThread(
                id: "t999",
                llm: "Gemini",
                messages: [
                    "Solve this for me: If I have 17 apples and I eat 3, how many apples do I have?",
                    "Also, does it change if the apples are imaginary?",
                    "Ok. Final: are imaginary apples still apples?"
                ]
            )
        )
        .preferredColorScheme(.dark)
    }
}
