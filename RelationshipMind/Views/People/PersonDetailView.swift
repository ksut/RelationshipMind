import SwiftUI
import SwiftData

struct PersonDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTouchpoints: [Touchpoint]
    @Bindable var person: Person
    @Environment(\.openURL) private var openURL
    @AppStorage("useWhatsApp") private var useWhatsApp: Bool = false
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
        VStack(spacing: 10) {
            // Contact actions — icon-only compact row
            HStack(spacing: 16) {
                if let phone = person.phoneNumber, !phone.isEmpty {
                    contactAction(icon: "phone.fill", label: "Call", color: .green) {
                        let cleaned = phone.replacingOccurrences(of: " ", with: "")
                        if let url = URL(string: "tel:\(cleaned)") { openURL(url) }
                        logQuickTouchpoint(type: .phoneCall, note: "Phone call made")
                    }

                    contactAction(icon: "message.fill", label: "Message", color: .blue) {
                        let cleaned = phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
                        if let url = URL(string: "sms:\(cleaned)") { openURL(url) }
                        logQuickTouchpoint(type: .text, note: "Text message sent")
                    }

                    if useWhatsApp {
                        contactAction(icon: "ellipsis.message.fill", label: "WhatsApp", color: .green) {
                            let cleaned = phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
                            let waNumber = cleaned.hasPrefix("+") ? String(cleaned.dropFirst()) : cleaned
                            if let url = URL(string: "https://wa.me/\(waNumber)") { openURL(url) }
                            logQuickTouchpoint(type: .whatsapp, note: "WhatsApp message sent")
                        }
                    }
                }

                if let email = person.email, !email.isEmpty {
                    contactAction(icon: "envelope.fill", label: "Email", color: .orange) {
                        if let url = URL(string: "mailto:\(email)") { openURL(url) }
                        logQuickTouchpoint(type: .email, note: "Email sent")
                    }
                }
            }

            // Log interaction button
            Button {
                showingLogTouchpoint = true
            } label: {
                Label("Log Interaction", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func contactAction(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(width: 50)
        }
        .buttonStyle(.plain)
    }

    private func logQuickTouchpoint(type: InteractionType, note: String) {
        let touchpoint = Touchpoint(
            rawNote: note,
            summary: note,
            interactionType: type,
            primaryPerson: person
        )
        modelContext.insert(touchpoint)
        person.touchpoints.append(touchpoint)
    }

    private var factsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Facts")
                .font(.headline)
                .foregroundColor(.secondary)

            FactsPanel(allFacts: person.facts)
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
                            NavigationLink {
                                PersonDetailView(person: relatedPerson)
                            } label: {
                                HStack {
                                    PersonAvatarView(person: relatedPerson, size: 32)
                                    VStack(alignment: .leading) {
                                        Text(relatedPerson.displayName)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Text(relationship.relationshipType)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
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
