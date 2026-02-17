import Foundation

/// A custom metric defined by the user to track progress for a specific skill.
/// Stored as JSON in the `custom_metrics` column of `skill_goals`.
struct CustomMetric: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var unit: String
    var targetValue: Double?
    var currentValue: Double?
    var isHigherBetter: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        unit: String,
        targetValue: Double? = nil,
        currentValue: Double? = nil,
        isHigherBetter: Bool = true
    ) {
        self.id = id
        self.name = name
        self.unit = unit
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.isHigherBetter = isHigherBetter
    }
}
