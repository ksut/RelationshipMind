import SwiftUI

struct FactsPanel: View {
    let facts: [Fact]

    var groupedFacts: [(FactCategory, [Fact])] {
        let grouped = Dictionary(grouping: facts) { $0.category }
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
                        FactRowView(fact: fact)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
}

struct FactRowView: View {
    let fact: Fact

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(fact.key.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)

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

    return FactsPanel(facts: facts)
        .padding()
}
