import Foundation
import SQLite3

/// Initial schema migration — creates the `skill_goals` table.
struct Migration_v1 {

    static let version = 1

    static func apply(db: OpaquePointer) throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS \(DatabaseSchema.SkillGoals.tableName) (
            \(DatabaseSchema.SkillGoals.id)               INTEGER PRIMARY KEY AUTOINCREMENT,
            \(DatabaseSchema.SkillGoals.skillName)        TEXT NOT NULL,
            \(DatabaseSchema.SkillGoals.skillDescription) TEXT,
            \(DatabaseSchema.SkillGoals.skillCategory)    TEXT,
            \(DatabaseSchema.SkillGoals.currentLevel)     TEXT,
            \(DatabaseSchema.SkillGoals.targetLevel)      TEXT,
            \(DatabaseSchema.SkillGoals.customMetrics)    TEXT,
            \(DatabaseSchema.SkillGoals.createdAt)        DATETIME DEFAULT CURRENT_TIMESTAMP,
            \(DatabaseSchema.SkillGoals.updatedAt)        DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.migrationFailed(version, msg)
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.migrationFailed(version, msg)
        }
    }
}
