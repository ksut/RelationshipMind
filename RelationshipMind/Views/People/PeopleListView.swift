import SwiftUI
import SwiftData

struct PeopleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.firstName) private var people: [Person]
    @State private var searchText = ""
    @State private var selectedFilter: PersonFilter = .all
    @State private var showingAddPerson = false

    // Multi-select state
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []

    // Sync state
    @State private var contactSyncService = ContactSyncService()
    @State private var isSyncing = false
    @State private var syncResult: SyncResult?
    @State private var syncError: Error?
    @State private var showingSyncAlert = false

    enum PersonFilter: String, CaseIterable {
        case all = "All"
        case tracked = "Tracked"
        case phoneContacts = "Contacts"
        case appLocal = "App Only"
    }

    var filteredPeople: [Person] {
        var result = people

        // Apply source filter
        switch selectedFilter {
        case .all:
            break
        case .tracked:
            result = result.filter { $0.isTracked }
        case .phoneContacts:
            result = result.filter { $0.source == .phoneContact }
        case .appLocal:
            result = result.filter { $0.source == .appLocal }
        }

        // Apply search
        if !searchText.isEmpty {
            result = result.filter { person in
                person.displayName.localizedCaseInsensitiveContains(searchText) ||
                (person.phoneNumber?.contains(searchText) ?? false) ||
                (person.email?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    var groupedPeople: [(String, [Person])] {
        let grouped = Dictionary(grouping: filteredPeople) { person in
            String(person.firstName.prefix(1)).uppercased()
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var phoneContactCount: Int {
        people.filter { $0.source == .phoneContact }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if people.isEmpty {
                    emptyStateView
                } else {
                    peopleListContent
                }
            }
            .navigationTitle("People")
            .searchable(text: $searchText, prompt: "Search people")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isSelecting {
                        Button("Done") {
                            exitSelectionMode()
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button {
                            syncContacts()
                        } label: {
                            if isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                        }
                        .disabled(isSyncing)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !isSelecting {
                        Button {
                            showingAddPerson = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                AddPersonView()
            }
            .alert("Contact Sync", isPresented: $showingSyncAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = syncError {
                    Text(error.localizedDescription)
                } else if let result = syncResult {
                    Text(result.description)
                }
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No People Yet", systemImage: "person.2")
        } description: {
            Text("Sync your contacts or add people manually to get started")
        } actions: {
            Button {
                syncContacts()
            } label: {
                if isSyncing {
                    ProgressView()
                        .padding(.horizontal)
                } else {
                    Text("Sync Contacts")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSyncing)

            Button("Add Person") {
                showingAddPerson = true
            }
            .buttonStyle(.bordered)
        }
    }

    private var peopleListContent: some View {
        VStack(spacing: 0) {
            // Filter picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(PersonFilter.allCases, id: \.self) { filter in
                    Text(filterLabel(for: filter)).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // People list
            List {
                ForEach(groupedPeople, id: \.0) { section in
                    Section(section.0) {
                        ForEach(section.1) { person in
                            if isSelecting {
                                Button {
                                    toggleSelection(person)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: selectedIDs.contains(person.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundColor(selectedIDs.contains(person.id) ? .accentColor : .secondary)
                                        PersonRowView(person: person)
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    PersonDetailView(person: person)
                                } label: {
                                    PersonRowView(person: person)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        toggleTracking(person)
                                    } label: {
                                        Label(
                                            person.isTracked ? "Untrack" : "Track",
                                            systemImage: person.isTracked ? "eye.slash" : "eye"
                                        )
                                    }
                                    .tint(person.isTracked ? .gray : .blue)
                                }
                                .onLongPressGesture {
                                    enterSelectionMode(startingWith: person)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            if !isSelecting {
                                deletePeople(from: section.1, at: indexSet)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            // Bulk action bar
            if isSelecting {
                bulkActionBar
            }
        }
    }

    private var bulkActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                Button {
                    selectAll()
                } label: {
                    Text(selectedIDs.count == filteredPeople.count ? "Deselect All" : "Select All")
                        .font(.subheadline)
                }

                Spacer()

                Text("\(selectedIDs.count) selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    trackSelected()
                } label: {
                    Text("Track")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .disabled(selectedIDs.isEmpty)

                Button {
                    untrackSelected()
                } label: {
                    Text("Untrack")
                        .font(.subheadline)
                }
                .disabled(selectedIDs.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    var trackedCount: Int {
        people.filter { $0.isTracked }.count
    }

    private func filterLabel(for filter: PersonFilter) -> String {
        switch filter {
        case .all:
            return "All (\(people.count))"
        case .tracked:
            return "Tracked (\(trackedCount))"
        case .phoneContacts:
            return "Contacts (\(phoneContactCount))"
        case .appLocal:
            return "App (\(people.count - phoneContactCount))"
        }
    }

    private func toggleTracking(_ person: Person) {
        person.isTracked.toggle()
        HapticService.selection()
    }

    private func enterSelectionMode(startingWith person: Person) {
        HapticService.mediumImpact()
        selectedIDs = [person.id]
        isSelecting = true
    }

    private func exitSelectionMode() {
        isSelecting = false
        selectedIDs.removeAll()
    }

    private func toggleSelection(_ person: Person) {
        HapticService.lightImpact()
        if selectedIDs.contains(person.id) {
            selectedIDs.remove(person.id)
        } else {
            selectedIDs.insert(person.id)
        }
    }

    private func selectAll() {
        if selectedIDs.count == filteredPeople.count {
            selectedIDs.removeAll()
        } else {
            selectedIDs = Set(filteredPeople.map { $0.id })
        }
        HapticService.lightImpact()
    }

    private func trackSelected() {
        for person in people where selectedIDs.contains(person.id) {
            person.isTracked = true
        }
        HapticService.success()
        exitSelectionMode()
    }

    private func untrackSelected() {
        for person in people where selectedIDs.contains(person.id) {
            person.isTracked = false
        }
        HapticService.success()
        exitSelectionMode()
    }

    private func deletePeople(from sectionPeople: [Person], at offsets: IndexSet) {
        HapticService.warning()
        for index in offsets {
            let person = sectionPeople[index]
            modelContext.delete(person)
        }
    }

    private func syncContacts() {
        isSyncing = true
        syncResult = nil
        syncError = nil

        Task { @MainActor in
            do {
                let result = try await contactSyncService.syncContacts(modelContext: modelContext)
                syncResult = result
                HapticService.success()
                showingSyncAlert = true
                isSyncing = false
            } catch {
                syncError = error
                showingSyncAlert = true
                isSyncing = false
            }
        }
    }
}

struct PersonRowView: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            PersonAvatarView(person: person, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(person.displayName)
                        .font(.body)

                    if person.source == .appLocal {
                        Image(systemName: "app.badge")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if person.touchpointCount > 0 {
                    Text("\(person.touchpointCount) interaction\(person.touchpointCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No interactions yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if person.isTracked {
                Image(systemName: "eye.fill")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PeopleListView()
        .modelContainer(for: [Person.self, Touchpoint.self, Fact.self, PersonRelationship.self], inMemory: true)
}
