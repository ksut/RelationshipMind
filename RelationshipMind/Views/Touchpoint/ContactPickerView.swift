import SwiftUI
import SwiftData

struct ContactPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.firstName) private var people: [Person]
    @State private var searchText = ""

    let onSelect: (Person) -> Void

    var filteredPeople: [Person] {
        if searchText.isEmpty {
            return people
        }
        return people.filter { person in
            person.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var groupedPeople: [(String, [Person])] {
        let grouped = Dictionary(grouping: filteredPeople) { person in
            String(person.firstName.prefix(1)).uppercased()
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        Group {
            if people.isEmpty {
                emptyStateView
            } else {
                peopleList
            }
        }
        .searchable(text: $searchText, prompt: "Search people")
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No People", systemImage: "person.2")
        } description: {
            Text("Add people first to log interactions")
        }
    }

    private var peopleList: some View {
        List {
            ForEach(groupedPeople, id: \.0) { section in
                Section(section.0) {
                    ForEach(section.1) { person in
                        Button {
                            onSelect(person)
                        } label: {
                            HStack(spacing: 12) {
                                PersonAvatarView(person: person, size: 40)

                                Text(person.displayName)
                                    .font(.body)
                                    .foregroundColor(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

#Preview {
    ContactPickerView { person in
        print("Selected: \(person.displayName)")
    }
    .modelContainer(for: Person.self, inMemory: true)
}
