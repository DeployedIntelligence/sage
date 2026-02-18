import SwiftUI

/// Step 1 — the user names their skill and optionally adds a description and category.
struct SkillInputView: View {

    @ObservedObject var vm: OnboardingViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case skillName, description, category
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            heading

            VStack(alignment: .leading, spacing: 20) {
                skillNameField
                descriptionField
                categoryField
            }
        }
        .onAppear { focusedField = .skillName }
    }

    // MARK: - Heading

    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What skill do you want to master?")
                .font(.title2)
                .fontWeight(.bold)

            Text("Be specific — the more detail you give, the better Sage can guide you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Skill Name

    private var skillNameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Skill name", systemImage: "star.fill")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            TextField("e.g. Fingerpicking Guitar", text: $vm.skillName)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .focused($focusedField, equals: .skillName)
                .submitLabel(.next)
                .onSubmit { focusedField = .description }
        }
    }

    // MARK: - Description

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Description (optional)", systemImage: "text.alignleft")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                if vm.skillDescription.isEmpty {
                    Text("What do you want to achieve?")
                        .font(.body)
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $vm.skillDescription)
                    .font(.body)
                    .frame(minHeight: 88)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .focused($focusedField, equals: .description)
                    .scrollContentBackground(.hidden)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Category

    private var categoryField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Category (optional)", systemImage: "tag.fill")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            TextField("e.g. Music, Language, Fitness", text: $vm.skillCategory)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .focused($focusedField, equals: .category)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
        }
    }
}

#Preview {
    let vm = OnboardingViewModel()
    return ScrollView {
        SkillInputView(vm: vm)
            .padding(24)
    }
}
