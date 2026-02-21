import SwiftUI

struct ExtractionResult {
    var summary: String
    var mentionedPeople: [MentionedPerson]
    var facts: [ExtractedFact]

    struct MentionedPerson: Identifiable {
        let id = UUID()
        var name: String
        var relationshipToPrimary: String?
        var isPrimary: Bool
        var matchedPerson: Person?
        var isConfirmed: Bool = false
    }

    struct ExtractedFact: Identifiable {
        let id = UUID()
        var personName: String
        var category: FactCategory
        var key: String
        var value: String
        var factDate: Date?
        var isTimeSensitive: Bool
        var timeProgression: TimeProgression?
        var confidence: Double
        var isConfirmed: Bool = true
    }
}

struct ExtractionReviewView: View {
    let touchpoint: Touchpoint
    @Binding var extraction: ExtractionResult
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                // Summary section
                Section("Summary") {
                    Text(extraction.summary)
                        .font(.body)
                }

                // Mentioned people section
                if !extraction.mentionedPeople.isEmpty {
                    Section("People Mentioned") {
                        ForEach($extraction.mentionedPeople) { $person in
                            MentionedPersonRow(person: $person)
                        }
                    }
                }

                // Extracted facts section
                if !extraction.facts.isEmpty {
                    Section("Extracted Facts") {
                        ForEach($extraction.facts) { $fact in
                            ExtractedFactRow(fact: $fact)
                        }
                    }
                }

                // Original note
                Section("Original Note") {
                    Text(touchpoint.rawNote)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Review Extraction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm", action: onConfirm)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct MentionedPersonRow: View {
    @Binding var person: ExtractionResult.MentionedPerson

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(person.name)
                        .font(.headline)
                    if person.isPrimary {
                        Text("Primary")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                }

                if let relationship = person.relationshipToPrimary {
                    Text(relationship)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let matched = person.matchedPerson {
                    Label("Matched: \(matched.displayName)", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("New person - will be created", systemImage: "plus.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            Toggle("", isOn: $person.isConfirmed)
                .labelsHidden()
        }
    }
}

struct ExtractedFactRow: View {
    @Binding var fact: ExtractionResult.ExtractedFact

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: fact.category.icon)
                        .foregroundColor(.accentColor)
                        .font(.caption)
                    Text(fact.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Confidence indicator
                    Text("\(Int(fact.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(fact.confidence >= 0.8 ? .green : .orange)
                }

                Text("\(fact.key): \(fact.value)")
                    .font(.body)

                Text("About: \(fact.personName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $fact.isConfirmed)
                .labelsHidden()
        }
    }
}

#Preview {
    @Previewable @State var extraction = ExtractionResult(
        summary: "Had a productive meeting with John about his new role at Apple",
        mentionedPeople: [
            .init(name: "John", relationshipToPrimary: nil, isPrimary: true, matchedPerson: nil),
            .init(name: "Sarah", relationshipToPrimary: "colleague", isPrimary: false, matchedPerson: nil)
        ],
        facts: [
            .init(personName: "John", category: .career, key: "company", value: "Apple", isTimeSensitive: false, confidence: 0.95),
            .init(personName: "John", category: .career, key: "role", value: "Senior Engineer", isTimeSensitive: false, confidence: 0.85)
        ]
    )

    let touchpoint = Touchpoint(rawNote: "Met with John today. He told me about his new job at Apple as a Senior Engineer. His colleague Sarah was also there.")

    return ExtractionReviewView(
        touchpoint: touchpoint,
        extraction: $extraction,
        onConfirm: {},
        onCancel: {}
    )
}
