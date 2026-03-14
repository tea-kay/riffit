import SwiftUI

/// Step 2 of onboarding: the AI interview.
/// A conversational chat interface where Claude asks the creator
/// questions one at a time to build their CreatorProfile.
/// The conversation is resumable — if the user leaves and comes back,
/// their OnboardingSession history is loaded and the chat continues.
struct InterviewView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Chat messages
            chatMessages

            // Input bar at the bottom
            inputBar
        }
        .background(Color.riffitBackground)
        .onAppear {
            // Start the interview with the first AI message if empty
            if viewModel.messages.isEmpty {
                Task {
                    await viewModel.startInterview()
                }
            }
        }
    }

    // MARK: - Chat Messages

    private var chatMessages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: .md) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    // Show typing indicator when waiting for AI response
                    if viewModel.isWaitingForAI {
                        TypingIndicator()
                            .id("typing")
                    }
                }
                .padding(.horizontal, .md)
                .padding(.vertical, .md)
            }
            .onChange(of: viewModel.messages.count) {
                // Auto-scroll to the latest message
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isWaitingForAI) {
                if viewModel.isWaitingForAI {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.riffitBorderSubtle)

            HStack(spacing: .smPlus) {
                TextField("Type your response...", text: $viewModel.currentInput, axis: .vertical)
                    .lineLimit(1...5)
                    .riffitBody()
                    .padding(.smPlus)
                    .background(Color.riffitSurface)
                    .cornerRadius(.inputRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: .inputRadius)
                            .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                    )
                    .focused($isInputFocused)

                // Send button
                Button {
                    Task {
                        await viewModel.sendMessage()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(sendButtonColor)
                }
                .disabled(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isWaitingForAI)
            }
            .padding(.horizontal, .md)
            .padding(.vertical, .smPlus)
        }
        .background(Color.riffitBackground)
    }

    private var sendButtonColor: Color {
        let isEmpty = viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isEmpty || viewModel.isWaitingForAI {
            return Color.riffitTextTertiary
        }
        return Color.riffitPrimary
    }
}

// MARK: - Chat Message Model

/// A single message in the interview conversation.
struct ChatMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date

    enum MessageRole {
        case user
        case assistant
    }

    init(role: MessageRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

// MARK: - Message Bubble

/// Displays a single chat message with different styling
/// for user vs assistant messages.
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            Text(message.content)
                .riffitBody()
                .foregroundStyle(foregroundColor)
                .padding(.smPlus)
                .background(backgroundColor)
                .cornerRadius(.inputRadius)

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return Color.riffitPrimaryTint
        case .assistant:
            return Color.riffitSurface
        }
    }

    private var foregroundColor: Color {
        return Color.riffitTextPrimary
    }
}

// MARK: - Typing Indicator

/// Animated dots showing the AI is thinking.
struct TypingIndicator: View {
    @State private var dotCount: Int = 0

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.riffitTextTertiary)
                        .frame(width: 8, height: 8)
                        .opacity(dotOpacity(for: index))
                }
            }
            .padding(.smPlus)
            .background(Color.riffitSurface)
            .cornerRadius(.inputRadius)

            Spacer(minLength: 60)
        }
        .onAppear {
            startAnimation()
        }
    }

    private func dotOpacity(for index: Int) -> Double {
        // Each dot pulses at a slightly different phase
        let phase = (dotCount + index) % 3
        switch phase {
        case 0: return 1.0
        case 1: return 0.5
        default: return 0.2
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                dotCount += 1
            }
        }
    }
}
