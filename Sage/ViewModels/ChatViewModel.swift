import Foundation

/// Drives the Chat tab.
///
/// Responsibilities:
/// - Load or create a `Conversation` for the active `SkillGoal`.
/// - Persist and expose `Message` rows.
/// - Forward the full conversation history to `ClaudeService` on each send.
@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: - Published state

    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Private state

    private var conversation: Conversation?
    private let skillGoal: SkillGoal
    private let db: DatabaseService
    private let claude: ClaudeService

    // MARK: - Init

    init(
        skillGoal: SkillGoal,
        db: DatabaseService = .shared,
        claude: ClaudeService = .shared
    ) {
        self.skillGoal = skillGoal
        self.db = db
        self.claude = claude
    }

    // MARK: - Lifecycle

    /// Call once when the view appears. Loads the most recent conversation (or creates one).
    func loadConversation() async {
        do {
            guard let goalId = skillGoal.id else { return }
            var convs = try db.fetchConversations(skillGoalId: goalId)

            if convs.isEmpty {
                let newConv = try db.insert(
                    Conversation(skillGoalId: goalId, title: nil)
                )
                convs = [newConv]
            }

            conversation = convs[0]
            guard let convId = conversation?.id else { return }
            messages = try db.fetchMessages(conversationId: convId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Actions

    /// Sends the current `inputText` to Claude using SSE streaming.
    ///
    /// The assistant reply appears token-by-token: a placeholder `Message` is inserted
    /// immediately and its `content` is grown in place as chunks arrive.
    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }
        guard let convId = conversation?.id else { return }

        inputText = ""
        errorMessage = nil

        // 1. Persist & show the user message immediately for instant UI feedback.
        var userMsg = Message(conversationId: convId, role: .user, content: text)
        do {
            userMsg = try db.insert(userMsg)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        messages.append(userMsg)

        isLoading = true
        defer { isLoading = false }

        // 2. Insert an empty assistant placeholder so the bubble appears straight away.
        var assistantMsg = Message(conversationId: convId, role: .assistant, content: "")
        do {
            assistantMsg = try db.insert(assistantMsg)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        messages.append(assistantMsg)

        // 3. Stream chunks from Claude, appending each to the last message.
        do {
            let systemPrompt = PromptTemplates.coachSystem(
                skillName: skillGoal.skillName,
                currentLevel: skillGoal.currentLevel,
                targetLevel: skillGoal.targetLevel,
                metrics: skillGoal.customMetrics
            )

            let stream = claude.streamConversation(
                messages: messages.dropLast(), // exclude the empty placeholder
                systemPrompt: systemPrompt
            )

            for try await chunk in stream {
                // Grow the last message's content in place — SwiftUI re-renders automatically.
                if let lastIndex = messages.indices.last {
                    messages[lastIndex].content += chunk
                }
            }

            // 4. Persist the fully-assembled assistant reply to the database.
            if let lastIndex = messages.indices.last {
                try db.updateMessageContent(messages[lastIndex])
            }
        } catch {
            // On error remove the empty/partial assistant bubble and surface a message.
            if messages.last?.role == .assistant {
                let partial = messages.removeLast()
                if let id = partial.id {
                    try? db.deleteMessage(id: id)
                }
            }
            errorMessage = friendlyError(error)
        }
    }

    // MARK: - Helpers

    private func friendlyError(_ error: Error) -> String {
        if let netErr = error as? NetworkError {
            switch netErr {
            case .missingAPIKey:
                return "No API key found. Add one in Settings."
            case .invalidAPIKey:
                return "Invalid API key. Check your key in Settings."
            case .rateLimited:
                return "Too many requests. Please wait a moment and try again."
            case .noConnection:
                return "No internet connection."
            case .timeout:
                return "Request timed out. Please try again."
            default:
                return "Something went wrong. Please try again."
            }
        }
        return error.localizedDescription
    }
}
