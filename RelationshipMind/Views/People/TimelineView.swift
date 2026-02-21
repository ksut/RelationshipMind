import SwiftUI

struct TimelineView: View {
    let touchpoints: [Touchpoint]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(touchpoints) { touchpoint in
                TimelineItemView(touchpoint: touchpoint)
            }
        }
    }
}

struct TimelineItemView: View {
    let touchpoint: Touchpoint

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: touchpoint.occurredAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                // Interaction type badge
                HStack(spacing: 4) {
                    Image(systemName: touchpoint.interactionType.icon)
                        .font(.caption)
                    Text(touchpoint.interactionType.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor)
                .cornerRadius(6)

                Spacer()

                // Date
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Note content
            if let summary = touchpoint.summary, !summary.isEmpty {
                Text(summary)
                    .font(.body)
                    .foregroundColor(.primary)
            } else {
                Text(touchpoint.rawNote)
                    .font(.body)
                    .foregroundColor(.primary)
            }

            // Facts indicator
            if !touchpoint.extractedFacts.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("\(touchpoint.extractedFacts.count) fact\(touchpoint.extractedFacts.count == 1 ? "" : "s") extracted")
                        .font(.caption)
                }
                .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    let person = Person(firstName: "John", lastName: "Doe")
    let touchpoints = [
        Touchpoint(
            rawNote: "Had coffee with John to discuss his new project at the startup. He mentioned they're looking for funding.",
            summary: "Coffee meeting about new project",
            interactionType: .inPerson,
            occurredAt: Date(),
            primaryPerson: person
        ),
        Touchpoint(
            rawNote: "Quick phone call about weekend plans",
            interactionType: .phoneCall,
            occurredAt: Date().addingTimeInterval(-86400 * 3),
            primaryPerson: person
        )
    ]

    return TimelineView(touchpoints: touchpoints)
        .padding()
}
