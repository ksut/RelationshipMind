import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query(sort: \Person.firstName) private var people: [Person]
    @Query(sort: \Touchpoint.occurredAt, order: .reverse) private var touchpoints: [Touchpoint]
    @Query private var facts: [Fact]
    @AppStorage("needsAttentionDays") private var needsAttentionDays: Int = 30

    var trackedPeople: [Person] {
        people.filter { $0.isTracked }
    }

    /// Only real interactions (excludes notes), only for tracked people
    var interactions: [Touchpoint] {
        let trackedIDs = Set(trackedPeople.map { $0.id })
        return touchpoints.filter {
            $0.interactionType.countsAsInteraction &&
            ($0.primaryPerson.map { trackedIDs.contains($0.id) } ?? false)
        }
    }

    var totalInteractions: Int {
        interactions.count
    }

    var activePeopleList: [Person] {
        let activeIDs = Set(interactions.compactMap { $0.primaryPerson?.id })
        return trackedPeople.filter { activeIDs.contains($0.id) }
    }

    var recentTouchpoints: [Touchpoint] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return interactions.filter { $0.occurredAt >= weekAgo }
    }

    var needsAttentionList: [(Person, Int)] {
        let threshold = Calendar.current.date(byAdding: .day, value: -needsAttentionDays, to: Date()) ?? Date()
        var result: [(Person, Int)] = []
        for person in trackedPeople {
            let personInteractions = interactions.filter { $0.primaryPerson?.id == person.id }
            if !personInteractions.isEmpty {
                let mostRecent = personInteractions.map { $0.occurredAt }.max() ?? Date.distantPast
                if mostRecent < threshold {
                    let daysSince = Calendar.current.dateComponents([.day], from: mostRecent, to: Date()).day ?? 0
                    result.append((person, daysSince))
                }
            }
        }
        return result.sorted { $0.1 > $1.1 }
    }

    var activeFacts: [Fact] {
        let trackedIDs = Set(trackedPeople.map { $0.id })
        return facts.filter { !$0.isSuperseded && ($0.person.map { trackedIDs.contains($0.id) } ?? false) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    statsSection
                    comingSoonSection
                }
                .padding()
            }
            .navigationTitle("Insights")
        }
    }

    private var statsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                NavigationLink {
                    InsightPeopleList(people: trackedPeople)
                } label: {
                    StatCard(
                        title: "Tracked",
                        value: "\(trackedPeople.count)",
                        icon: "person.2.fill",
                        color: .blue
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    InsightTouchpointList(
                        title: "All Interactions",
                        touchpoints: interactions
                    )
                } label: {
                    StatCard(
                        title: "Interactions",
                        value: "\(totalInteractions)",
                        icon: "bubble.left.and.bubble.right.fill",
                        color: .green
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 16) {
                NavigationLink {
                    InsightPeopleList(
                        people: activePeopleList,
                        title: "Active Contacts"
                    )
                } label: {
                    StatCard(
                        title: "Active Contacts",
                        value: "\(activePeopleList.count)",
                        icon: "person.crop.circle.badge.checkmark",
                        color: .purple
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    InsightTouchpointList(
                        title: "This Week",
                        touchpoints: recentTouchpoints
                    )
                } label: {
                    StatCard(
                        title: "This Week",
                        value: "\(recentTouchpoints.count)",
                        icon: "calendar",
                        color: .orange
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 16) {
                NavigationLink {
                    InsightNeedsAttentionList(
                        people: needsAttentionList,
                        thresholdDays: needsAttentionDays
                    )
                } label: {
                    StatCard(
                        title: "Needs Attention",
                        value: "\(needsAttentionList.count)",
                        icon: "bell.badge",
                        color: .red
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    InsightFactsList(facts: activeFacts)
                } label: {
                    StatCard(
                        title: "Facts Tracked",
                        value: "\(activeFacts.count)",
                        icon: "sparkles",
                        color: .teal
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var comingSoonSection: some View {
        VStack(spacing: 16) {
            ContentUnavailableView {
                Label("Analytics Coming Soon", systemImage: "chart.bar.xaxis")
            } description: {
                Text("Relationship analytics, contact frequency trends, and more will be available in a future update")
            }
        }
        .padding(.top, 40)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Detail Views

struct InsightPeopleList: View {
    let people: [Person]
    var title: String = "All People"

    var body: some View {
        List {
            ForEach(people) { person in
                NavigationLink {
                    PersonDetailView(person: person)
                } label: {
                    HStack(spacing: 12) {
                        PersonAvatarView(person: person, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.displayName)
                                .font(.body)
                            HStack(spacing: 8) {
                                if person.source == .appLocal {
                                    Text("App Contact")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                if person.touchpointCount > 0 {
                                    Text("\(person.touchpointCount) interaction\(person.touchpointCount == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if people.isEmpty {
                ContentUnavailableView("No People", systemImage: "person.2", description: Text("No people to show"))
            }
        }
    }
}

struct InsightTouchpointList: View {
    let title: String
    let touchpoints: [Touchpoint]

    var body: some View {
        List {
            ForEach(touchpoints) { touchpoint in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if let person = touchpoint.primaryPerson {
                            Text(person.displayName)
                                .font(.headline)
                        }
                        Spacer()
                        Text(touchpoint.interactionType.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12))
                            .cornerRadius(6)
                    }

                    if let summary = touchpoint.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    } else {
                        Text(touchpoint.rawNote)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Text(touchpoint.occurredAt, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if touchpoints.isEmpty {
                ContentUnavailableView("No Interactions", systemImage: "bubble.left.and.bubble.right", description: Text("No interactions to show"))
            }
        }
    }
}

struct InsightNeedsAttentionList: View {
    let people: [(Person, Int)]
    let thresholdDays: Int

    var body: some View {
        List {
            ForEach(people, id: \.0.id) { person, daysSince in
                NavigationLink {
                    PersonDetailView(person: person)
                } label: {
                    HStack(spacing: 12) {
                        PersonAvatarView(person: person, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.displayName)
                                .font(.body)
                            Text("\(daysSince) days since last contact")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Circle()
                            .fill(urgencyColor(daysSince))
                            .frame(width: 10, height: 10)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Needs Attention")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if people.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("All Caught Up")
                        .font(.headline)
                    Text("No one has gone \(thresholdDays)+ days without contact")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }

    private func urgencyColor(_ days: Int) -> Color {
        if days > 90 { return .red }
        else if days > 60 { return .orange }
        else { return .yellow }
    }
}

struct InsightFactsList: View {
    let facts: [Fact]

    private var groupedByPerson: [(Person, [Fact])] {
        let grouped = Dictionary(grouping: facts) { $0.person?.id ?? UUID() }
        return grouped.compactMap { (_, personFacts) -> (Person, [Fact])? in
            guard let person = personFacts.first?.person else { return nil }
            return (person, personFacts.sorted { $0.category.rawValue < $1.category.rawValue })
        }
        .sorted { $0.0.displayName < $1.0.displayName }
    }

    var body: some View {
        List {
            ForEach(groupedByPerson, id: \.0.id) { person, personFacts in
                Section {
                    ForEach(personFacts) { fact in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fact.key.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(fact.computeCurrentValue())
                                    .font(.body)
                            }
                            Spacer()
                            Label(fact.category.rawValue, systemImage: fact.category.icon)
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                                .labelStyle(.iconOnly)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    HStack(spacing: 8) {
                        PersonAvatarView(person: person, size: 24)
                        Text(person.displayName)
                    }
                }
            }
        }
        .navigationTitle("Facts Tracked")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if facts.isEmpty {
                ContentUnavailableView("No Facts", systemImage: "sparkles", description: Text("Facts will appear as you log interactions"))
            }
        }
    }
}

#Preview {
    InsightsView()
        .modelContainer(for: [Person.self, Touchpoint.self, Fact.self, PersonRelationship.self], inMemory: true)
}
