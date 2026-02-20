import XCTest
@testable import Sage

final class MessageTests: XCTestCase {

    // MARK: - Initialization

    func testInit_defaultValues() {
        let msg = Message(conversationId: 1, role: .user, content: "Hello")

        XCTAssertNil(msg.id)
        XCTAssertEqual(msg.conversationId, 1)
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.content, "Hello")
    }

    func testInit_assistantRole() {
        let msg = Message(conversationId: 2, role: .assistant, content: "Hi there!")

        XCTAssertEqual(msg.role, .assistant)
        XCTAssertFalse(msg.role.isUser)
    }

    // MARK: - Role

    func testRole_isUser_trueForUser() {
        XCTAssertTrue(Message.Role.user.isUser)
    }

    func testRole_isUser_falseForAssistant() {
        XCTAssertFalse(Message.Role.assistant.isUser)
    }

    func testRole_rawValue_user() {
        XCTAssertEqual(Message.Role.user.rawValue, "user")
    }

    func testRole_rawValue_assistant() {
        XCTAssertEqual(Message.Role.assistant.rawValue, "assistant")
    }

    func testRole_initFromRawValue_validString() {
        XCTAssertEqual(Message.Role(rawValue: "user"), .user)
        XCTAssertEqual(Message.Role(rawValue: "assistant"), .assistant)
    }

    func testRole_initFromRawValue_invalidString_returnsNil() {
        XCTAssertNil(Message.Role(rawValue: "system"))
        XCTAssertNil(Message.Role(rawValue: ""))
    }

    // MARK: - Equatable

    func testMessage_equatable_sameValues() {
        let date = Date()
        let a = Message(id: 1, conversationId: 1, role: .user, content: "Hi", createdAt: date)
        let b = Message(id: 1, conversationId: 1, role: .user, content: "Hi", createdAt: date)
        XCTAssertEqual(a, b)
    }

    func testMessage_equatable_differentContent() {
        let a = Message(conversationId: 1, role: .user, content: "Hello")
        let b = Message(conversationId: 1, role: .user, content: "Goodbye")
        XCTAssertNotEqual(a, b)
    }

    func testMessage_equatable_differentRole() {
        let a = Message(conversationId: 1, role: .user,      content: "Hi")
        let b = Message(conversationId: 1, role: .assistant, content: "Hi")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Conversation model

    func testConversation_defaultValues() {
        let conv = Conversation(skillGoalId: 42, title: "Session 1")

        XCTAssertNil(conv.id)
        XCTAssertEqual(conv.skillGoalId, 42)
        XCTAssertEqual(conv.title, "Session 1")
    }

    func testConversation_displayTitle_usesTitle() {
        let conv = Conversation(title: "My Session")
        XCTAssertEqual(conv.displayTitle, "My Session")
    }

    func testConversation_displayTitle_fallsBackToDate_whenTitleNil() {
        let conv = Conversation(title: nil)
        // The fallback is a non-empty formatted date string — just verify it's non-empty.
        XCTAssertFalse(conv.displayTitle.isEmpty)
    }

    func testConversation_displayTitle_fallsBackToDate_whenTitleEmpty() {
        let conv = Conversation(title: "")
        XCTAssertFalse(conv.displayTitle.isEmpty)
    }
}
