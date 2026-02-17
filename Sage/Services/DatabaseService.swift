import Foundation
import SQLite3

/// Thread-safe SQLite wrapper providing CRUD operations for Sage's local database.
///
/// The database file lives in the app's Documents directory so it persists across
/// launches and is excluded from iCloud backup by default.
///
/// Pass a custom `url` to the initializer to use a non-default path (e.g. in tests).
final class DatabaseService {

    // MARK: - Singleton

    static let shared = DatabaseService()

    // MARK: - Private state

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.sage.database", qos: .utility)
    private let customURL: URL?

    // MARK: - Init

    /// - Parameter url: Override the database file location. Defaults to `Documents/sage.db`.
    init(url: URL? = nil) {
        self.customURL = url
    }

    // MARK: - Lifecycle

    /// Opens (or creates) the SQLite database and runs any pending migrations.
    func open() throws {
        let url = customURL ?? (try databaseURL())
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK, let db else {
            throw DatabaseError.connectionFailed("Could not open database at \(url.path)")
        }

        // Enable WAL mode for better concurrent read performance.
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)

        try runMigrations()
    }

    /// Closes the database connection. Call from app teardown if needed.
    func close() {
        queue.sync {
            if let db {
                sqlite3_close(db)
                self.db = nil
            }
        }
    }

    // MARK: - SkillGoal CRUD

    /// Inserts a new SkillGoal and returns the saved copy with its generated `id`.
    @discardableResult
    func insert(_ goal: SkillGoal) throws -> SkillGoal {
        try queue.sync {
            guard let db else { throw DatabaseError.connectionFailed("Database not open") }

            let metricsJSON = try goal.customMetricsJSON()
            let sql = """
            INSERT INTO \(DatabaseSchema.SkillGoals.tableName)
                (\(DatabaseSchema.SkillGoals.skillName),
                 \(DatabaseSchema.SkillGoals.skillDescription),
                 \(DatabaseSchema.SkillGoals.skillCategory),
                 \(DatabaseSchema.SkillGoals.currentLevel),
                 \(DatabaseSchema.SkillGoals.targetLevel),
                 \(DatabaseSchema.SkillGoals.customMetrics),
                 \(DatabaseSchema.SkillGoals.createdAt),
                 \(DatabaseSchema.SkillGoals.updatedAt))
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """

            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.insertFailed(errmsg(db))
            }

            bind(stmt, 1, goal.skillName)
            bind(stmt, 2, goal.skillDescription)
            bind(stmt, 3, goal.skillCategory)
            bind(stmt, 4, goal.currentLevel)
            bind(stmt, 5, goal.targetLevel)
            bind(stmt, 6, metricsJSON)
            bind(stmt, 7, iso8601(goal.createdAt))
            bind(stmt, 8, iso8601(goal.updatedAt))

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.insertFailed(errmsg(db))
            }

            let rowID = sqlite3_last_insert_rowid(db)
            var saved = goal
            saved.id = rowID
            return saved
        }
    }

    /// Returns all SkillGoals ordered by most recently created.
    func fetchAll() throws -> [SkillGoal] {
        try queue.sync {
            guard let db else { throw DatabaseError.connectionFailed("Database not open") }

            let sql = """
            SELECT \(DatabaseSchema.SkillGoals.id),
                   \(DatabaseSchema.SkillGoals.skillName),
                   \(DatabaseSchema.SkillGoals.skillDescription),
                   \(DatabaseSchema.SkillGoals.skillCategory),
                   \(DatabaseSchema.SkillGoals.currentLevel),
                   \(DatabaseSchema.SkillGoals.targetLevel),
                   \(DatabaseSchema.SkillGoals.customMetrics),
                   \(DatabaseSchema.SkillGoals.createdAt),
                   \(DatabaseSchema.SkillGoals.updatedAt)
            FROM \(DatabaseSchema.SkillGoals.tableName)
            ORDER BY \(DatabaseSchema.SkillGoals.createdAt) DESC;
            """

            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.queryFailed(errmsg(db))
            }

            var results: [SkillGoal] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(try rowToSkillGoal(stmt))
            }
            return results
        }
    }

    /// Returns the SkillGoal with the given `id`, or throws `DatabaseError.notFound`.
    func fetch(id: Int64) throws -> SkillGoal {
        try queue.sync {
            guard let db else { throw DatabaseError.connectionFailed("Database not open") }

            let sql = """
            SELECT \(DatabaseSchema.SkillGoals.id),
                   \(DatabaseSchema.SkillGoals.skillName),
                   \(DatabaseSchema.SkillGoals.skillDescription),
                   \(DatabaseSchema.SkillGoals.skillCategory),
                   \(DatabaseSchema.SkillGoals.currentLevel),
                   \(DatabaseSchema.SkillGoals.targetLevel),
                   \(DatabaseSchema.SkillGoals.customMetrics),
                   \(DatabaseSchema.SkillGoals.createdAt),
                   \(DatabaseSchema.SkillGoals.updatedAt)
            FROM \(DatabaseSchema.SkillGoals.tableName)
            WHERE \(DatabaseSchema.SkillGoals.id) = ?;
            """

            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.queryFailed(errmsg(db))
            }

            sqlite3_bind_int64(stmt, 1, id)

            guard sqlite3_step(stmt) == SQLITE_ROW else {
                throw DatabaseError.notFound
            }

            return try rowToSkillGoal(stmt)
        }
    }

    /// Updates an existing SkillGoal. The goal must have a non-nil `id`.
    func update(_ goal: SkillGoal) throws {
        try queue.sync {
            guard let db else { throw DatabaseError.connectionFailed("Database not open") }
            guard let goalID = goal.id else {
                throw DatabaseError.updateFailed("SkillGoal has no id")
            }

            let metricsJSON = try goal.customMetricsJSON()
            let now = Date()
            let sql = """
            UPDATE \(DatabaseSchema.SkillGoals.tableName)
            SET \(DatabaseSchema.SkillGoals.skillName)        = ?,
                \(DatabaseSchema.SkillGoals.skillDescription) = ?,
                \(DatabaseSchema.SkillGoals.skillCategory)    = ?,
                \(DatabaseSchema.SkillGoals.currentLevel)     = ?,
                \(DatabaseSchema.SkillGoals.targetLevel)      = ?,
                \(DatabaseSchema.SkillGoals.customMetrics)    = ?,
                \(DatabaseSchema.SkillGoals.updatedAt)        = ?
            WHERE \(DatabaseSchema.SkillGoals.id) = ?;
            """

            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.updateFailed(errmsg(db))
            }

            bind(stmt, 1, goal.skillName)
            bind(stmt, 2, goal.skillDescription)
            bind(stmt, 3, goal.skillCategory)
            bind(stmt, 4, goal.currentLevel)
            bind(stmt, 5, goal.targetLevel)
            bind(stmt, 6, metricsJSON)
            bind(stmt, 7, iso8601(now))
            sqlite3_bind_int64(stmt, 8, goalID)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.updateFailed(errmsg(db))
            }
        }
    }

    /// Deletes the SkillGoal with the given `id`.
    func delete(id: Int64) throws {
        try queue.sync {
            guard let db else { throw DatabaseError.connectionFailed("Database not open") }

            let sql = """
            DELETE FROM \(DatabaseSchema.SkillGoals.tableName)
            WHERE \(DatabaseSchema.SkillGoals.id) = ?;
            """

            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.deleteFailed(errmsg(db))
            }

            sqlite3_bind_int64(stmt, 1, id)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.deleteFailed(errmsg(db))
            }
        }
    }

    // MARK: - Migrations

    private func runMigrations() throws {
        guard let db else { return }

        // Use SQLite's built-in user_version pragma to track schema version.
        let currentVersion = userVersion()

        if currentVersion < 1 {
            try Migration_v1.apply(db: db)
            setUserVersion(1)
        }
        // Future: if currentVersion < 2 { try Migration_v2.apply(db: db) ... }
    }

    private func userVersion() -> Int {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &stmt, nil)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private func setUserVersion(_ version: Int) {
        guard let db else { return }
        sqlite3_exec(db, "PRAGMA user_version = \(version);", nil, nil, nil)
    }

    // MARK: - Helpers

    private func databaseURL() throws -> URL {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw DatabaseError.connectionFailed("Documents directory unavailable")
        }
        return docs.appendingPathComponent("sage.db")
    }

    /// Reads a row from a prepared statement into a SkillGoal.
    private func rowToSkillGoal(_ stmt: OpaquePointer?) throws -> SkillGoal {
        let id          = sqlite3_column_int64(stmt, 0)
        let skillName   = string(stmt, 1) ?? ""
        let description = string(stmt, 2)
        let category    = string(stmt, 3)
        let currentLvl  = string(stmt, 4)
        let targetLvl   = string(stmt, 5)
        let metricsJSON = string(stmt, 6) ?? "[]"
        let createdStr  = string(stmt, 7) ?? ""
        let updatedStr  = string(stmt, 8) ?? ""

        let metrics = try SkillGoal.decodeMetrics(from: metricsJSON)
        let createdAt = parseISO8601(createdStr) ?? Date()
        let updatedAt = parseISO8601(updatedStr) ?? Date()

        return SkillGoal(
            id: id,
            skillName: skillName,
            skillDescription: description,
            skillCategory: category,
            currentLevel: currentLvl,
            targetLevel: targetLvl,
            customMetrics: metrics,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - SQLite binding helpers

    private func bind(_ stmt: OpaquePointer?, _ idx: Int32, _ value: String?) {
        if let v = value {
            sqlite3_bind_text(stmt, idx, (v as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, idx)
        }
    }

    private func string(_ stmt: OpaquePointer?, _ idx: Int32) -> String? {
        guard let cStr = sqlite3_column_text(stmt, idx) else { return nil }
        return String(cString: cStr)
    }

    private func errmsg(_ db: OpaquePointer?) -> String {
        guard let db else { return "unknown error" }
        return String(cString: sqlite3_errmsg(db))
    }

    // MARK: - Date helpers

    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func iso8601(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private func parseISO8601(_ string: String) -> Date? {
        // Try with fractional seconds first, fall back to plain ISO 8601.
        if let d = dateFormatter.date(from: string) { return d }
        let fallback = ISO8601DateFormatter()
        return fallback.date(from: string)
    }
}
