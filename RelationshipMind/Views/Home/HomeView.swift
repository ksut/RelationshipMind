import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Touchpoint.occurredAt, order: .reverse) private var allTouchpoints: [Touchpoint]
    @Query(sort: \Person.firstName) private var allPeople: [Person]
    @State private var showingLogTouchpoint = false
    @State private var showingAddNote = false
    @State private var showingSettings = false
    @AppStorage("needsAttentionDays") private var needsAttentionDays: Int = 30

    // People with recent interactions, sorted by most recent (excludes notes, only tracked)
    var recentPeople: [(Person, Int, Date)] {
        var peopleWithStats: [(Person, Int, Date)] = []

        for person in allPeople where person.isTracked {
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

    /// People with at least 1 interaction whose most recent interaction is older than the threshold.
    /// Notes don't count — only real interactions. Sorted most stale first.
    var needsAttentionPeople: [(Person, Int)] {
        let threshold = Calendar.current.date(byAdding: .day, value: -needsAttentionDays, to: Date()) ?? Date()

        return recentPeople
            .filter { $0.2 < threshold }
            .map { person, _, lastDate in
                let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
                return (person, daysSince)
            }
            .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Quick Capture Button
                    quickCaptureSection

                    // Recent Touchpoints
                    recentTouchpointsSection

                    // Needs Attention
                    needsAttentionSection
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

    private var needsAttentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Needs Attention")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(needsAttentionDays)+ days")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }

            if needsAttentionPeople.isEmpty {
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
            } else {
                ForEach(needsAttentionPeople.prefix(5), id: \.0.id) { person, daysSince in
                    NavigationLink {
                        PersonDetailView(person: person)
                    } label: {
                        NeedsAttentionCard(person: person, daysSince: daysSince)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct NeedsAttentionCard: View {
    let person: Person
    let daysSince: Int

    private var urgencyColor: Color {
        if daysSince > 90 {
            return .red
        } else if daysSince > 60 {
            return .orange
        } else {
            return .yellow
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            PersonAvatarView(person: person, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(daysSince) days since last contact")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Circle()
                .fill(urgencyColor)
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
