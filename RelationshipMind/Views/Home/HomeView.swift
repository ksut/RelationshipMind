import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Touchpoint.occurredAt, order: .reverse) private var allTouchpoints: [Touchpoint]
    @Query(sort: \Person.firstName) private var allPeople: [Person]
    @State private var showingLogTouchpoint = false
    @State private var showingSettings = false

    // People with recent interactions, sorted by most recent
    var recentPeople: [(Person, Int, Date)] {
        var peopleWithStats: [(Person, Int, Date)] = []

        for person in allPeople {
            let touchpoints = allTouchpoints.filter { $0.primaryPerson?.id == person.id }
            if !touchpoints.isEmpty {
                let count = touchpoints.count
                let mostRecent = touchpoints.map { $0.occurredAt }.max() ?? Date.distantPast
                peopleWithStats.append((person, count, mostRecent))
            }
        }

        return peopleWithStats.sorted { $0.2 > $1.2 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Quick Capture Button
                    quickCaptureSection

                    // Recent Touchpoints
                    recentTouchpointsSection

                    // Needs Attention (placeholder for now)
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
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private var quickCaptureSection: some View {
        Button {
            showingLogTouchpoint = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Log Interaction")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
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
            Text("Needs Attention")
                .font(.headline)
                .foregroundColor(.secondary)

            ContentUnavailableView(
                "Coming Soon",
                systemImage: "bell.badge",
                description: Text("People you haven't contacted in a while will appear here")
            )
            .frame(height: 150)
        }
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
