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
        try db.insert(SkillGoal(skillName: "First"))
        // Small sleep so timestamps differ (SQLite datetime has 1-second resolution
        // for DEFAULT CURRENT_TIMESTAMP, but we set explicit ISO8601 dates).
        let older = SkillGoal(skillName: "Older", createdAt: Date(timeIntervalSinceNow: -60))
        let newer = SkillGoal(skillName: "Newer", createdAt: Date())
        try db.insert(older)
        try db.insert(newer)

        let results = try db.fetchAll()
        // Most-recently created should come first.
        XCTAssertEqual(results.first?.skillName, "Newer")
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
}

// MARK: - DatabaseError Equatable (test helper)

extension DatabaseError: Equatable {
    public static func == (lhs: DatabaseError, rhs: DatabaseError) -> Bool {
        switch (lhs, rhs) {
        case (.notFound, .notFound): return true
        case (.connectionFailed, .connectionFailed): return true
        default: return false
        }
    }
}
