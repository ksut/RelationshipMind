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
        var fuzzyMatches: [FuzzyMatch]
        var isConfirmed: Bool = true
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
                Section("Summary") {
                    Text(extraction.summary)
                        .font(.body)
                }

                if !extraction.mentionedPeople.isEmpty {
                    Section("People Mentioned") {
                        ForEach($extraction.mentionedPeople) { $person in
                            MentionedPersonRow(person: $person)
                        }
                    }
                }

                if !extraction.facts.isEmpty {
                    Section("Extracted Facts") {
                        ForEach($extraction.facts) { $fact in
                            ExtractedFactRow(fact: $fact)
                        }
                    }
                }

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
                    Button("Skip", action: onCancel)
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

    private var hasFuzzyMatches: Bool {
        person.matchedPerson == nil && !person.fuzzyMatches.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

                    // Match status
                    if let matched = person.matchedPerson {
                        Label("Matched: \(matched.displayName)", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else if person.fuzzyMatches.isEmpty {
                        Label("New person — will be created", systemImage: "plus.circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Label("Multiple possible matches", systemImage: "questionmark.circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                if !person.isPrimary {
                    Toggle("", isOn: $person.isConfirmed)
                        .labelsHidden()
                }
            }

            // Show fuzzy match options when there are multiple possible matches
            if !person.isPrimary && hasFuzzyMatches {
                let matches = Array(person.fuzzyMatches.prefix(3))
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(matches.enumerated()), id: \.offset) { _, match in
                        Button {
                            person.matchedPerson = match.person
                        } label: {
                            HStack {
                                Image(systemName: "person.circle")
                                    .foregroundColor(.accentColor)
                                Text(match.person.displayName)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(Int(match.score * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        person.matchedPerson = nil
                        person.fuzzyMatches = []
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.orange)
                            Text("Create new person")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
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
            .init(name: "John", relationshipToPrimary: nil, isPrimary: true, matchedPerson: nil, fuzzyMatches: []),
            .init(name: "Sarah", relationshipToPrimary: "colleague", isPrimary: false, matchedPerson: nil, fuzzyMatches: [])
        ],
        facts: [
            .init(personName: "John", category: .career, key: "company", value: "Apple", isTimeSensitive: false, confidence: 0.95),
            .init(personName: "John", category: .career, key: "role", value: "Senior Engineer", isTimeSensitive: false, confidence: 0.85)
        ]
    )

    let touchpoint = Touchpoint(rawNote: "Met with John today. He told me about his new job at Apple as a Senior Engineer. His colleague Sarah was also there.")

    ExtractionReviewView(
        touchpoint: touchpoint,
        extraction: $extraction,
        onConfirm: {},
        onCancel: {}
    )
}
