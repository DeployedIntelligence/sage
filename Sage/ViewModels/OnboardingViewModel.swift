import Foundation
import Combine

/// Manages state and validation for the multi-step onboarding flow.
@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - Step

    enum Step: Int, CaseIterable {
        case skillInput = 0
        case levelSelection = 1
        case metricSelection = 2

        var title: String {
            switch self {
            case .skillInput:      return "Your Skill"
            case .levelSelection:  return "Your Level"
            case .metricSelection: return "Track Progress"
            }
        }

        var next: Step? { Step(rawValue: rawValue + 1) }
        var previous: Step? { Step(rawValue: rawValue - 1) }
    }

    // MARK: - Published State

    @Published var currentStep: Step = .skillInput
    @Published var isComplete: Bool = false

    // Step 1 — Skill Input
    @Published var skillName: String = ""
    @Published var skillDescription: String = ""
    @Published var skillCategory: String = ""

    // Step 2 — Level Selection
    @Published var currentLevel: String = ""
    @Published var targetLevel: String = ""

    // Step 3 — Metric Selection
    @Published var metrics: [CustomMetric] = []

    // Transient metric builder
    @Published var newMetricName: String = ""
    @Published var newMetricUnit: String = ""
    @Published var newMetricIsHigherBetter: Bool = true

    // MARK: - Computed

    var progress: Double {
        Double(currentStep.rawValue + 1) / Double(Step.allCases.count)
    }

    var isCurrentStepValid: Bool {
        switch currentStep {
        case .skillInput:
            return !skillName.trimmingCharacters(in: .whitespaces).isEmpty
        case .levelSelection:
            return !currentLevel.isEmpty && !targetLevel.isEmpty
        case .metricSelection:
            return true  // Optional — user may skip adding metrics
        }
    }

    var isNewMetricValid: Bool {
        !newMetricName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !newMetricUnit.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Navigation

    func advance() {
        guard isCurrentStepValid else { return }
        if let next = currentStep.next {
            currentStep = next
        } else {
            finish()
        }
    }

    func goBack() {
        if let previous = currentStep.previous {
            currentStep = previous
        }
    }

    // MARK: - Metric Management

    func addMetric() {
        guard isNewMetricValid else { return }
        let metric = CustomMetric(
            name: newMetricName.trimmingCharacters(in: .whitespaces),
            unit: newMetricUnit.trimmingCharacters(in: .whitespaces),
            isHigherBetter: newMetricIsHigherBetter
        )
        metrics.append(metric)
        clearMetricDraft()
    }

    func removeMetric(at offsets: IndexSet) {
        metrics.remove(atOffsets: offsets)
    }

    func clearMetricDraft() {
        newMetricName = ""
        newMetricUnit = ""
        newMetricIsHigherBetter = true
    }

    // MARK: - Finish

    private func finish() {
        let goal = buildSkillGoal()
        save(goal)
        isComplete = true
    }

    func buildSkillGoal() -> SkillGoal {
        SkillGoal(
            skillName: skillName.trimmingCharacters(in: .whitespaces),
            skillDescription: skillDescription.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : skillDescription.trimmingCharacters(in: .whitespaces),
            skillCategory: skillCategory.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : skillCategory.trimmingCharacters(in: .whitespaces),
            currentLevel: currentLevel.isEmpty ? nil : currentLevel,
            targetLevel: targetLevel.isEmpty ? nil : targetLevel,
            customMetrics: metrics
        )
    }

    private func save(_ goal: SkillGoal) {
        do {
            _ = try DatabaseService.shared.insertSkillGoal(goal)
        } catch {
            // Surface to error state in a future sprint.
            print("[OnboardingViewModel] Failed to save goal: \(error.localizedDescription)")
        }
    }
}
