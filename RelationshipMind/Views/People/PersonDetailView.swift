import SwiftUI
import SwiftData

struct PersonDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTouchpoints: [Touchpoint]
    @Bindable var person: Person
    @State private var showingLogTouchpoint = false
    @State private var isTimelineExpanded = false

    var personTouchpoints: [Touchpoint] {
        allTouchpoints
            .filter { $0.primaryPerson?.id == person.id }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    var activeFacts: [Fact] {
        person.facts.filter { !$0.isSuperseded }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                quickActionsSection

                if !activeFacts.isEmpty {
                    factsSection
                }

                timelineSection

                if !person.relationships.isEmpty {
                    connectedPeopleSection
                }
            }
            .padding()
        }
        .navigationTitle(person.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingLogTouchpoint) {
            LogTouchpointView(preselectedPerson: person)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            PersonAvatarView(person: person, size: 80)

            VStack(spacing: 4) {
                Text(person.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)

                if person.source == .phoneContact {
                    Label("Phone Contact", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Label("App Contact", systemImage: "app.badge")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 16) {
                if let phone = person.phoneNumber {
                    Label(phone, systemImage: "phone.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let email = person.email {
                    Label(email, systemImage: "envelope.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var quickActionsSection: some View {
        HStack(spacing: 16) {
            Button {
                showingLogTouchpoint = true
            } label: {
                Label("Log Interaction", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var factsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Facts")
                .font(.headline)
                .foregroundColor(.secondary)

            FactsPanel(facts: activeFacts)
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTimelineExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Timeline")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(personTouchpoints.count) interaction\(personTouchpoints.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Image(systemName: isTimelineExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isTimelineExpanded {
                if personTouchpoints.isEmpty {
                    ContentUnavailableView(
                        "No Interactions",
                        systemImage: "clock",
                        description: Text("Log your first interaction with \(person.firstName)")
                    )
                    .frame(height: 150)
                } else {
                    TimelineView(touchpoints: personTouchpoints)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var connectedPeopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected People")
                .font(.headline)
                .foregroundColor(.secondary)

            if person.relationships.isEmpty {
                ContentUnavailableView(
                    "No Connections",
                    systemImage: "person.2",
                    description: Text("Relationships will appear here as they're discovered")
                )
                .frame(height: 100)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(person.relationships) { relationship in
                        if let relatedPerson = relationship.relatedPerson {
                            HStack {
                                PersonAvatarView(person: relatedPerson, size: 32)
                                VStack(alignment: .leading) {
                                    Text(relatedPerson.displayName)
                                        .font(.subheadline)
                                    Text(relationship.relationshipType)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    let person = Person(firstName: "John", lastName: "Doe", source: .phoneContact)
    return NavigationStack {
        PersonDetailView(person: person)
    }
    .modelContainer(for: [Person.self, Touchpoint.self, Fact.self, PersonRelationship.self], inMemory: true)
}
