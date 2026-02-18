import SwiftUI

/// Displays a single CustomMetric in a list row.
struct MetricRow: View {

    let metric: CustomMetric

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: metric.isHigherBetter ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(metric.isHigherBetter ? Color.green : Color.orange)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(metric.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(metric.unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        MetricRow(metric: CustomMetric(name: "Words per minute", unit: "wpm", isHigherBetter: true))
        MetricRow(metric: CustomMetric(name: "Error rate", unit: "%", isHigherBetter: false))
    }
}
