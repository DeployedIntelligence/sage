import SwiftUI

/// Step 2 — the user picks their current level and target level for the skill.
struct LevelSelectionView: View {

    @ObservedObject var vm: OnboardingViewModel

    private let levels: [String] = [
        "Beginner",
        "Novice",
        "Intermediate",
        "Advanced",
        "Expert"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            heading
            currentLevelSection
            targetLevelSection
        }
    }

    // MARK: - Heading

    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Where are you starting from?")
                .font(.title2)
                .fontWeight(.bold)

            Text("Pick your current level and where you want to reach.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Current Level

    private var currentLevelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Current level", systemImage: "chart.bar.fill")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            levelGrid(selection: $vm.currentLevel, accent: .indigo, prefix: "current")
        }
    }

    // MARK: - Target Level

    private var targetLevelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Target level", systemImage: "flag.fill")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            levelGrid(selection: $vm.targetLevel, accent: Color.accentColor, prefix: "target")
        }
    }

    // MARK: - Level Grid

    private func levelGrid(selection: Binding<String>, accent: Color, prefix: String) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            ForEach(levels, id: \.self) { level in
                let isSelected = selection.wrappedValue == level
                Button(action: { selection.wrappedValue = level }) {
                    Text(level)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isSelected ? accent : Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? accent : Color.clear, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: isSelected)
                .accessibilityIdentifier("\(prefix)-\(level)")
            }
        }
    }
}

#Preview {
    let vm = OnboardingViewModel()
    return ScrollView {
        LevelSelectionView(vm: vm)
            .padding(24)
    }
}
