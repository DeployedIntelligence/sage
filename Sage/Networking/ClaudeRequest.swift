import Foundation

// MARK: - Request

/// Top-level request body sent to the Claude Messages API.
struct ClaudeRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [ClaudeMessage]
    /// When `true` the API returns a server-sent event stream instead of a single JSON blob.
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case stream
    }

    init(
        model: String,
        maxTokens: Int,
        system: String? = nil,
        messages: [ClaudeMessage],
        stream: Bool = false
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.system = system
        self.messages = messages
        self.stream = stream
    }
}

// MARK: - Message

/// A single turn in the conversation.
struct ClaudeMessage: Encodable {
    let role: Role
    let content: String

    enum Role: String, Encodable {
        case user
        case assistant
    }
}
