import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query private var people: [Person]
    @Query private var touchpoints: [Touchpoint]

    var totalInteractions: Int {
        touchpoints.count
    }

    var activePeople: Int {
        Set(touchpoints.compactMap { $0.primaryPerson?.id }).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Stats overview
                    statsSection

                    // Coming soon placeholder
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
                StatCard(
                    title: "People",
                    value: "\(people.count)",
                    icon: "person.2.fill",
                    color: .blue
                )
                StatCard(
                    title: "Interactions",
                    value: "\(totalInteractions)",
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .green
                )
            }

            HStack(spacing: 16) {
                StatCard(
                    title: "Active Contacts",
                    value: "\(activePeople)",
                    icon: "person.crop.circle.badge.checkmark",
                    color: .purple
                )
                StatCard(
                    title: "This Week",
                    value: "\(recentInteractionsCount)",
                    icon: "calendar",
                    color: .orange
                )
            }
        }
    }

    private var recentInteractionsCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return touchpoints.filter { $0.occurredAt >= weekAgo }.count
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
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

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

#Preview {
    InsightsView()
        .modelContainer(for: [Person.self, Touchpoint.self, Fact.self, PersonRelationship.self], inMemory: true)
}
