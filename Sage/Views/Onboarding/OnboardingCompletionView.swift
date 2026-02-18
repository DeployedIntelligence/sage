import SwiftUI

/// Shown after the user completes all onboarding steps.
/// Will transition to the main app experience in a future sprint.
struct OnboardingCompletionView: View {

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.bounce, value: true)

            VStack(spacing: 10) {
                Text("You're all set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Sage is ready to help you track your progress\nand reach your goals.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Placeholder CTA — navigation to main app wired in a future sprint.
            Button(action: {}) {
                Text("Let's go")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    OnboardingCompletionView()
}
