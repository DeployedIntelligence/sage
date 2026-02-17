import Foundation

/// The primary model representing a user's skill learning goal.
/// Maps directly to the `skill_goals` table.
struct SkillGoal: Codable, Identifiable, Equatable {
    var id: Int64?
    var skillName: String
    var skillDescription: String?
    var skillCategory: String?
    var currentLevel: String?
    var targetLevel: String?
    var customMetrics: [CustomMetric]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        skillName: String,
        skillDescription: String? = nil,
        skillCategory: String? = nil,
        currentLevel: String? = nil,
        targetLevel: String? = nil,
        customMetrics: [CustomMetric] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.skillName = skillName
        self.skillDescription = skillDescription
        self.skillCategory = skillCategory
        self.currentLevel = currentLevel
        self.targetLevel = targetLevel
        self.customMetrics = customMetrics
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Serializes `customMetrics` to a JSON string for SQLite storage.
    func customMetricsJSON() throws -> String {
        let data = try JSONEncoder().encode(customMetrics)
        guard let json = String(data: data, encoding: .utf8) else {
            throw DatabaseError.encodingFailed("customMetrics")
        }
        return json
    }

    /// Deserializes a JSON string into `[CustomMetric]`.
    static func decodeMetrics(from json: String) throws -> [CustomMetric] {
        guard let data = json.data(using: .utf8) else {
            throw DatabaseError.decodingFailed("customMetrics")
        }
        return try JSONDecoder().decode([CustomMetric].self, from: data)
    }
}
