import SwiftUI

/// Manages the entire onboarding flow state:
/// 1. Creator type selection
/// 2. AI interview conversation
/// 3. Social account connection (optional)
///
/// Communicates with the `run-interview` edge function to power
/// the conversational AI interview. The conversation is resumable
/// via OnboardingSession stored in Supabase.
@MainActor
class OnboardingViewModel: ObservableObject {
    // MARK: - Flow State

    /// The current step in the onboarding flow.
    @Published var currentStep: OnboardingStep = .creatorType
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // MARK: - Creator Type

    @Published var selectedCreatorType: CreatorProfile.CreatorType?

    // MARK: - Interview Chat

    @Published var messages: [ChatMessage] = []
    @Published var currentInput: String = ""
    @Published var isWaitingForAI: Bool = false
    @Published var isInterviewComplete: Bool = false

    // MARK: - Session Tracking

    /// The onboarding session ID from Supabase.
    /// Used to resume the conversation if the user leaves.
    var sessionId: UUID?

    /// The creator profile ID created when the interview completes.
    var creatorProfileId: UUID?

    // MARK: - Onboarding Steps

    enum OnboardingStep {
        case creatorType
        case interview
        case socialConnect
    }

    // MARK: - Creator Type Selection

    /// Called when the user taps a creator type card.
    /// Saves the selection and advances to the interview step.
    func selectCreatorType(_ type: CreatorProfile.CreatorType) {
        selectedCreatorType = type
        // TODO: Create OnboardingSession in Supabase with the selected creator type
        // For now, advance to the interview step
        withAnimation {
            currentStep = .interview
        }
    }

    // MARK: - Interview

    /// Kicks off the interview by sending the first message.
    /// The AI will respond with an opening question based on
    /// the selected creator type.
    func startInterview() async {
        guard let creatorType = selectedCreatorType else { return }

        isWaitingForAI = true

        // TODO: Call the run-interview edge function with an empty
        // user_message to get the opening question. The edge function
        // will pick the right prompt tree based on creator_type.
        //
        // let response = try await EdgeFunctions.shared.runInterview(
        //     sessionId: sessionId,
        //     userMessage: ""
        // )

        // Placeholder opening message based on creator type
        let openingMessage = openingMessageFor(creatorType: creatorType)

        // Simulate a brief delay for natural feel
        try? await Task.sleep(for: .seconds(1))

        let aiMessage = ChatMessage(role: .assistant, content: openingMessage)
        messages.append(aiMessage)
        isWaitingForAI = false
    }

    /// Sends the user's current input as a message in the interview.
    /// The AI will respond with the next question or complete the interview.
    func sendMessage() async {
        let text = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Add user message to chat
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        currentInput = ""
        isWaitingForAI = true

        // TODO: Call the run-interview edge function
        //
        // do {
        //     let response = try await EdgeFunctions.shared.runInterview(
        //         sessionId: sessionId!,
        //         userMessage: text
        //     )
        //     let aiMessage = ChatMessage(role: .assistant, content: response.aiMessage)
        //     messages.append(aiMessage)
        //
        //     if response.isComplete {
        //         isInterviewComplete = true
        //         creatorProfileId = response.creatorProfileId
        //     }
        // } catch {
        //     self.error = error
        // }

        // Placeholder: echo back a follow-up question
        try? await Task.sleep(for: .seconds(1))

        let followUp = generateFollowUp()
        let aiMessage = ChatMessage(role: .assistant, content: followUp)
        messages.append(aiMessage)
        isWaitingForAI = false
    }

    /// Advances from the interview to social account connection.
    func finishInterview() {
        withAnimation {
            currentStep = .socialConnect
        }
    }

    /// Called when the social connect step finishes (either connected or skipped).
    /// Returns the creator profile ID so AppState can complete onboarding.
    func finishOnboarding() -> UUID? {
        // TODO: Return the actual creator profile ID from the interview completion
        return creatorProfileId ?? UUID()
    }

    // MARK: - Placeholder Helpers

    /// Returns an opening message tailored to the creator type.
    /// This will be replaced by the actual AI response from the edge function.
    private func openingMessageFor(creatorType: CreatorProfile.CreatorType) -> String {
        switch creatorType {
        case .personalBrand:
            return "Hey! I'm excited to learn about you and your brand. Let's start with the big picture — what's the core message or mission behind your content? What do you want people to take away from everything you create?"
        case .educator:
            return "Hey! I'd love to understand what you teach and how you think about it. What's your area of expertise, and what transformation do you help your audience achieve?"
        case .entertainer:
            return "Hey! Let's talk about what makes your content unique. What's your style? Are you more sketch comedy, storytelling, commentary, or something completely different?"
        case .business:
            return "Hey! Let's dig into your business and how content fits into your strategy. What product or service do you offer, and what's the biggest pain point you solve for your customers?"
        case .agency:
            return "Hey! Running an agency means you're juggling multiple voices and brands. Let's start with your agency's positioning — what kinds of clients do you work with, and what results do you help them achieve?"
        }
    }

    /// Generates a placeholder follow-up question.
    /// Will be replaced by actual AI responses.
    private func generateFollowUp() -> String {
        let followUps = [
            "That's really interesting. Tell me more — what's a specific moment or experience that shaped how you think about this?",
            "Love that. Now, when it comes to your audience, who are you really trying to reach? Paint me a picture of your ideal viewer.",
            "Great answer. What are the topics you could talk about for hours? The things you always come back to in your content?",
            "That helps a lot. Here's a fun one — what's an opinion you hold that might be a bit controversial in your space?",
            "Almost done! What's something you'd never do in your content? Any hard lines you don't cross?",
        ]

        // Pick based on message count (simple rotation)
        let userMessageCount = messages.filter { $0.role == .user }.count
        let index = min(userMessageCount - 1, followUps.count - 1)
        return followUps[max(0, index)]
    }
}
