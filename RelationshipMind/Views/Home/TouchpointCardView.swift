import SwiftUI

struct TouchpointCardView: View {
    let touchpoint: Touchpoint

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: touchpoint.occurredAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with person and interaction type
            HStack {
                if let person = touchpoint.primaryPerson {
                    PersonAvatarView(person: person, size: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        HStack(spacing: 4) {
                            Image(systemName: touchpoint.interactionType.icon)
                                .font(.caption2)
                            Text(touchpoint.interactionType.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.gray)

                    Text("Unknown Person")
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                Spacer()

                // Date badge
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Note content
            if let summary = touchpoint.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            } else {
                Text(touchpoint.rawNote)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    let person = Person(firstName: "John", lastName: "Doe")
    let touchpoint = Touchpoint(
        rawNote: "Had a great conversation about his new job at Apple. He seems really excited about the role.",
        summary: "Discussed John's new role at Apple",
        interactionType: .phoneCall,
        primaryPerson: person
    )
    return TouchpointCardView(touchpoint: touchpoint)
        .padding()
        .background(Color(.systemGray6))
}
