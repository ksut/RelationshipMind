import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Touchpoint.occurredAt, order: .reverse) private var allTouchpoints: [Touchpoint]
    @Query(sort: \Person.firstName) private var allPeople: [Person]
    @State private var showingLogTouchpoint = false
    @State private var showingAddNote = false
    @State private var showingSettings = false

    var trackedPeople: [Person] {
        allPeople.filter { $0.isTracked }
    }

    // People with recent interactions, sorted by most recent (excludes notes, only tracked)
    var recentPeople: [(Person, Int, Date)] {
        var peopleWithStats: [(Person, Int, Date)] = []

        for person in trackedPeople {
            let interactions = allTouchpoints.filter {
                $0.primaryPerson?.id == person.id && $0.interactionType.countsAsInteraction
            }
            if !interactions.isEmpty {
                let count = interactions.count
                let mostRecent = interactions.map { $0.occurredAt }.max() ?? Date.distantPast
                peopleWithStats.append((person, count, mostRecent))
            }
        }

        return peopleWithStats.sorted { $0.2 > $1.2 }
    }

    /// Tracked people with zero real interactions
    var neverContactedPeople: [Person] {
        let contactedIDs = Set(recentPeople.map { $0.0.id })
        return trackedPeople
            .filter { !contactedIDs.contains($0.id) }
            .sorted { $0.firstName < $1.firstName }
    }

    /// Tracked people whose last real interaction was over 1 year ago
    var overOneYearPeople: [(Person, Int)] {
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        return recentPeople
            .filter { $0.2 < oneYearAgo }
            .map { person, _, lastDate in
                let days = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
                return (person, days)
            }
            .sorted { $0.1 > $1.1 }
    }

    /// Tracked people whose last real interaction was between 6 months and 1 year ago
    var overSixMonthsPeople: [(Person, Int)] {
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        return recentPeople
            .filter { $0.2 < sixMonthsAgo && $0.2 >= oneYearAgo }
            .map { person, _, lastDate in
                let days = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
                return (person, days)
            }
            .sorted { $0.1 > $1.1 }
    }

    var hasAnyAttentionItems: Bool {
        !neverContactedPeople.isEmpty || !overOneYearPeople.isEmpty || !overSixMonthsPeople.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Quick Capture Button
                    quickCaptureSection

                    // Recent Touchpoints
                    recentTouchpointsSection

                    // Attention groups
                    attentionSection
                }
                .padding()
            }
            .navigationTitle("RelationshipMind")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingLogTouchpoint) {
                LogTouchpointView()
            }
            .sheet(isPresented: $showingAddNote) {
                LogTouchpointView(isNoteOnly: true)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private var quickCaptureSection: some View {
        HStack(spacing: 10) {
            Button {
                showingLogTouchpoint = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Interaction")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            Button {
                showingAddNote = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Note")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }

    private var recentTouchpointsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.headline)
                .foregroundColor(.secondary)

            if recentPeople.isEmpty {
                ContentUnavailableView(
                    "No Interactions Yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Tap the button above to log your first interaction")
                )
                .frame(height: 200)
            } else {
                ForEach(recentPeople.prefix(10), id: \.0.id) { person, count, _ in
                    NavigationLink {
                        PersonDetailView(person: person)
                    } label: {
                        RecentPersonCard(person: person, touchpointCount: count)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !hasAnyAttentionItems {
                allCaughtUpView
            } else {
                if !neverContactedPeople.isEmpty {
                    attentionGroup(
                        title: "Never Connected",
                        icon: "person.fill.questionmark",
                        color: .red,
                        count: neverContactedPeople.count
                    ) {
                        ForEach(neverContactedPeople.prefix(5)) { person in
                            NavigationLink {
                                PersonDetailView(person: person)
                            } label: {
                                AttentionCard(person: person, subtitle: "No interactions yet", color: .red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !overOneYearPeople.isEmpty {
                    attentionGroup(
                        title: "Over 1 Year",
                        icon: "exclamationmark.triangle.fill",
                        color: .orange,
                        count: overOneYearPeople.count
                    ) {
                        ForEach(overOneYearPeople.prefix(5), id: \.0.id) { person, days in
                            NavigationLink {
                                PersonDetailView(person: person)
                            } label: {
                                AttentionCard(person: person, subtitle: "\(days) days ago", color: .orange)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !overSixMonthsPeople.isEmpty {
                    attentionGroup(
                        title: "Over 6 Months",
                        icon: "clock.badge.exclamationmark",
                        color: .yellow,
                        count: overSixMonthsPeople.count
                    ) {
                        ForEach(overSixMonthsPeople.prefix(5), id: \.0.id) { person, days in
                            NavigationLink {
                                PersonDetailView(person: person)
                            } label: {
                                AttentionCard(person: person, subtitle: "\(days) days ago", color: .yellow)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func attentionGroup<Content: View>(
        title: String,
        icon: String,
        color: Color,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.subheadline)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.15))
                    .cornerRadius(8)
            }

            content()
        }
    }

    private var allCaughtUpView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.green)
                Text("All Caught Up")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }
}

struct AttentionCard: View {
    let person: Person
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            PersonAvatarView(person: person, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct RecentPersonCard: View {
    let person: Person
    let touchpointCount: Int

    var body: some View {
        HStack(spacing: 12) {
            PersonAvatarView(person: person, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(touchpointCount) interaction\(touchpointCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Person.self, Touchpoint.self, Fact.self, PersonRelationship.self], inMemory: true)
}
