import SwiftUI

struct FactsPanel: View {
    let allFacts: [Fact]

    private var activeFacts: [Fact] {
        allFacts.filter { !$0.isSuperseded }
    }

    private var groupedFacts: [(FactCategory, [Fact])] {
        let grouped = Dictionary(grouping: activeFacts) { $0.category }
        return grouped.sorted { $0.key.rawValue < $1.key.rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(groupedFacts, id: \.0) { category, categoryFacts in
                VStack(alignment: .leading, spacing: 8) {
                    // Category header
                    Label(category.rawValue, systemImage: category.icon)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)

                    // Facts in this category
                    ForEach(categoryFacts) { fact in
                        FactRowView(
                            fact: fact,
                            supersededFacts: supersededChain(for: fact)
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }

    /// Finds all superseded facts with the same category + key, sorted newest first.
    private func supersededChain(for fact: Fact) -> [Fact] {
        allFacts
            .filter { $0.isSuperseded && $0.category == fact.category && $0.key == fact.key }
            .sorted { $0.extractedAt > $1.extractedAt }
    }
}

struct FactRowView: View {
    let fact: Fact
    var supersededFacts: [Fact] = []
    @State private var isHistoryExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(fact.key.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !supersededFacts.isEmpty {
                    Text("Updated")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(4)
                }

                Spacer()

                if fact.isTimeSensitive {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }

                // Confidence indicator
                if fact.confidence < 0.8 {
                    Image(systemName: "questionmark.circle")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }

            Text(fact.computeCurrentValue())
                .font(.body)

            if let factDate = fact.factDate {
                Text("Since \(factDate, style: .date)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Expandable superseded history
            if !supersededFacts.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHistoryExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isHistoryExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                        Text("\(supersededFacts.count) previous value\(supersededFacts.count == 1 ? "" : "s")")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                if isHistoryExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(supersededFacts) { oldFact in
                            HStack(spacing: 6) {
                                Text(oldFact.value)
                                    .font(.caption)
                                    .strikethrough()
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(oldFact.extractedAt, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                        }
                    }
                    .padding(.leading, 8)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let facts = [
        Fact(category: .career, key: "job_title", value: "Software Engineer", confidence: 0.95),
        Fact(category: .career, key: "company", value: "Apple", confidence: 1.0),
        Fact(category: .education, key: "college", value: "Stanford University", isTimeSensitive: false, confidence: 0.9),
        Fact(category: .location, key: "city", value: "San Francisco", confidence: 0.85)
    ]

    return FactsPanel(allFacts: facts)
        .padding()
}
