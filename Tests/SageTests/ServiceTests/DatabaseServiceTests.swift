import XCTest
@testable import Sage

final class DatabaseServiceTests: XCTestCase {

    // Each test gets a fresh in-memory-style database in a temp directory.
    private var db: DatabaseService!
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Each test gets its own isolated database file via the url initializer.
        let dbURL = tempDir.appendingPathComponent("test_sage.db")
        db = DatabaseService(url: dbURL)
        try db.open()
    }

    override func tearDownWithError() throws {
        db.close()
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Insert

    func testInsert_returnsGoalWithID() throws {
        let goal = SkillGoal(skillName: "Watercolor Painting")
        let saved = try db.insert(goal)

        XCTAssertNotNil(saved.id)
        XCTAssertEqual(saved.skillName, "Watercolor Painting")
    }

    func testInsert_withAllFields() throws {
        let metric = CustomMetric(name: "Brush strokes / min", unit: "strokes", targetValue: 100)
        let goal = SkillGoal(
            skillName: "Juggling",
            skillDescription: "3-ball cascade",
            skillCategory: "Physical",
            currentLevel: "Beginner",
            targetLevel: "Intermediate",
            customMetrics: [metric]
        )

        let saved = try db.insert(goal)

        XCTAssertNotNil(saved.id)
        XCTAssertEqual(saved.skillDescription, "3-ball cascade")
        XCTAssertEqual(saved.skillCategory, "Physical")
        XCTAssertEqual(saved.customMetrics.count, 1)
        XCTAssertEqual(saved.customMetrics.first?.name, "Brush strokes / min")
    }

    // MARK: - Fetch all

    func testFetchAll_emptyDatabase() throws {
        let results = try db.fetchAll()
        XCTAssertTrue(results.isEmpty)
    }

    func testFetchAll_returnsInsertedGoals() throws {
        try db.insert(SkillGoal(skillName: "Guitar"))
        try db.insert(SkillGoal(skillName: "Python"))

        let results = try db.fetchAll()
        XCTAssertEqual(results.count, 2)
    }

    func testFetchAll_orderedByCreatedAtDescending() throws {
        let now = Date()
        let oldest = SkillGoal(skillName: "Oldest", createdAt: now.addingTimeInterval(-120))
        let older  = SkillGoal(skillName: "Older",  createdAt: now.addingTimeInterval(-60))
        let newer  = SkillGoal(skillName: "Newer",  createdAt: now)

        try db.insert(oldest)
        try db.insert(older)
        try db.insert(newer)

        let results = try db.fetchAll()
        // Most-recently created should come first.
        XCTAssertEqual(results[0].skillName, "Newer")
        XCTAssertEqual(results[1].skillName, "Older")
        XCTAssertEqual(results[2].skillName, "Oldest")
    }

    // MARK: - Fetch by ID

    func testFetchByID_returnsCorrectGoal() throws {
        let saved = try db.insert(SkillGoal(skillName: "SQL"))
        let fetched = try db.fetch(id: saved.id!)

        XCTAssertEqual(fetched.skillName, "SQL")
    }

    func testFetchByID_throwsNotFoundForMissingID() throws {
        XCTAssertThrowsError(try db.fetch(id: 9999)) { error in
            XCTAssertEqual(error as? DatabaseError, .notFound)
        }
    }

    // MARK: - Update

    func testUpdate_persistsChanges() throws {
        var goal = try db.insert(SkillGoal(skillName: "Baking"))
        goal.skillDescription = "Sourdough bread"
        goal.targetLevel = "Advanced"

        try db.update(goal)

        let fetched = try db.fetch(id: goal.id!)
        XCTAssertEqual(fetched.skillDescription, "Sourdough bread")
        XCTAssertEqual(fetched.targetLevel, "Advanced")
    }

    func testUpdate_updatesCustomMetrics() throws {
        var goal = try db.insert(SkillGoal(skillName: "Running"))
        goal.customMetrics = [CustomMetric(name: "Pace", unit: "min/km", targetValue: 5.0)]

        try db.update(goal)

        let fetched = try db.fetch(id: goal.id!)
        XCTAssertEqual(fetched.customMetrics.count, 1)
        XCTAssertEqual(fetched.customMetrics.first?.targetValue, 5.0)
    }

    // MARK: - Delete

    func testDelete_removesGoal() throws {
        let saved = try db.insert(SkillGoal(skillName: "Chess"))
        try db.delete(id: saved.id!)

        let results = try db.fetchAll()
        XCTAssertTrue(results.isEmpty)
    }

    func testDelete_doesNotAffectOtherGoals() throws {
        let a = try db.insert(SkillGoal(skillName: "A"))
        let b = try db.insert(SkillGoal(skillName: "B"))

        try db.delete(id: a.id!)

        let results = try db.fetchAll()
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.skillName, "B")
        _ = b // suppress unused warning
    }

    // MARK: - Persistence simulation

    func testData_persistsAfterReopeningDatabase() throws {
        try db.insert(SkillGoal(skillName: "Persistence Test"))
        db.close()

        // Reopen the same database file.
        try db.open()

        let results = try db.fetchAll()
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.skillName, "Persistence Test")
    }

    // MARK: - Conversation insert

    func testInsertConversation_returnsConversationWithID() throws {
        let saved = try db.insert(Conversation(skillGoalId: nil, title: "Intro"))

        XCTAssertNotNil(saved.id)
        XCTAssertEqual(saved.title, "Intro")
    }

    func testInsertConversation_withSkillGoalId() throws {
        let goal = try db.insert(SkillGoal(skillName: "Piano"))
        let conv = try db.insert(Conversation(skillGoalId: goal.id, title: "Day 1"))

        XCTAssertEqual(conv.skillGoalId, goal.id)
    }

    // MARK: - Conversation fetch

    func testFetchConversations_emptyForUnknownGoal() throws {
        let results = try db.fetchConversations(skillGoalId: 9999)
        XCTAssertTrue(results.isEmpty)
    }

    func testFetchConversations_returnsOnlyMatchingGoal() throws {
        let goal1 = try db.insert(SkillGoal(skillName: "Guitar"))
        let goal2 = try db.insert(SkillGoal(skillName: "Piano"))
        try db.insert(Conversation(skillGoalId: goal1.id, title: "Guitar chat"))
        try db.insert(Conversation(skillGoalId: goal2.id, title: "Piano chat"))

        let results = try db.fetchConversations(skillGoalId: goal1.id!)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Guitar chat")
    }

    func testFetchConversations_multipleForSameGoal() throws {
        let goal = try db.insert(SkillGoal(skillName: "Drawing"))
        try db.insert(Conversation(skillGoalId: goal.id, title: "Session A"))
        try db.insert(Conversation(skillGoalId: goal.id, title: "Session B"))

        let results = try db.fetchConversations(skillGoalId: goal.id!)
        XCTAssertEqual(results.count, 2)
    }

    // MARK: - Conversation update title

    func testUpdateConversationTitle_persistsNewTitle() throws {
        let goal = try db.insert(SkillGoal(skillName: "Chess"))
        var conv = try db.insert(Conversation(skillGoalId: goal.id, title: "Old title"))
        conv.title = "New title"
        try db.updateConversationTitle(conv)

        let results = try db.fetchConversations(skillGoalId: goal.id!)
        XCTAssertEqual(results.first?.title, "New title")
    }

    // MARK: - Message insert

    func testInsertMessage_returnsMessageWithID() throws {
        let conv = try db.insert(Conversation(title: "Chat"))
        let msg = try db.insert(Message(conversationId: conv.id!, role: .user, content: "Hello"))

        XCTAssertNotNil(msg.id)
        XCTAssertEqual(msg.content, "Hello")
        XCTAssertEqual(msg.role, .user)
    }

    func testInsertMessage_bothRoles() throws {
        let conv = try db.insert(Conversation(title: "Chat"))
        let userMsg = try db.insert(Message(conversationId: conv.id!, role: .user, content: "Hi"))
        let assistantMsg = try db.insert(Message(conversationId: conv.id!, role: .assistant, content: "Hello!"))

        XCTAssertEqual(userMsg.role, .user)
        XCTAssertEqual(assistantMsg.role, .assistant)
    }

    // MARK: - Message fetch

    func testFetchMessages_emptyForNewConversation() throws {
        let conv = try db.insert(Conversation(title: "Empty"))
        let results = try db.fetchMessages(conversationId: conv.id!)
        XCTAssertTrue(results.isEmpty)
    }

    func testFetchMessages_returnsMessagesInChronologicalOrder() throws {
        let now = Date()
        let conv = try db.insert(Conversation(title: "Chat"))
        let convId = conv.id!
        try db.insert(Message(conversationId: convId, role: .user,      content: "First",  createdAt: now))
        try db.insert(Message(conversationId: convId, role: .assistant, content: "Second", createdAt: now.addingTimeInterval(1)))
        try db.insert(Message(conversationId: convId, role: .user,      content: "Third",  createdAt: now.addingTimeInterval(2)))

        let results = try db.fetchMessages(conversationId: convId)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].content, "First")
        XCTAssertEqual(results[1].content, "Second")
        XCTAssertEqual(results[2].content, "Third")
    }

    func testFetchMessages_isolatedToConversation() throws {
        let conv1 = try db.insert(Conversation(title: "Conv 1"))
        let conv2 = try db.insert(Conversation(title: "Conv 2"))
        try db.insert(Message(conversationId: conv1.id!, role: .user, content: "In conv1"))
        try db.insert(Message(conversationId: conv2.id!, role: .user, content: "In conv2"))

        let results = try db.fetchMessages(conversationId: conv1.id!)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.content, "In conv1")
    }

    // MARK: - Message insert touches parent updated_at

    func testInsertMessage_touchesConversationUpdatedAt() throws {
        let goal = try db.insert(SkillGoal(skillName: "Yoga"))
        let conv = try db.insert(Conversation(skillGoalId: goal.id, title: "Session"))
        let before = conv.updatedAt

        // Small delay so the timestamp can differ.
        Thread.sleep(forTimeInterval: 0.01)
        try db.insert(Message(conversationId: conv.id!, role: .user, content: "Hi"))

        let updated = try db.fetchConversations(skillGoalId: goal.id!).first
        XCTAssertNotNil(updated?.updatedAt)
        XCTAssertGreaterThanOrEqual(updated!.updatedAt, before)
    }
}
