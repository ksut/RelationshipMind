import Foundation
import Contacts
import SwiftData

@Observable
final class ContactSyncService {
    private let contactStore = CNContactStore()

    var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    // MARK: - Authorization

    func requestAccess() async -> Bool {
        do {
            let granted = try await contactStore.requestAccess(for: .contacts)
            return granted
        } catch {
            print("Contact access request failed: \(error)")
            return false
        }
    }

    // MARK: - Sync Contacts

    private nonisolated func fetchContacts() throws -> [CNContact] {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactRelationsKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var contacts: [CNContact] = []
        try contactStore.enumerateContacts(with: request) { contact, _ in
            if !contact.givenName.isEmpty || !contact.familyName.isEmpty {
                contacts.append(contact)
            }
        }
        return contacts
    }

    @MainActor
    func syncContacts(modelContext: ModelContext) async throws -> SyncResult {
        if !isAuthorized {
            let granted = await requestAccess()
            if !granted {
                throw ContactSyncError.notAuthorized
            }
        }

        let fetchedContacts = try await Task.detached { [self] in
            try self.fetchContacts()
        }.value

        // Get existing synced contacts from database
        // Note: Fetch all and filter in memory because SwiftData predicates can't compare enum cases
        let allDescriptor = FetchDescriptor<Person>()
        let allPeople = try modelContext.fetch(allDescriptor)
        let existingPeople = allPeople.filter { $0.source == .phoneContact }
        let existingByIdentifier = Dictionary(
            uniqueKeysWithValues: existingPeople.compactMap { person -> (String, Person)? in
                guard let identifier = person.contactIdentifier else { return nil }
                return (identifier, person)
            }
        )

        var added = 0
        var updated = 0
        var relationships: [(CNContact, CNLabeledValue<CNContactRelation>)] = []

        for contact in fetchedContacts {
            if let existingPerson = existingByIdentifier[contact.identifier] {
                // Update existing
                if updatePerson(existingPerson, from: contact) {
                    updated += 1
                }
            } else {
                // Create new
                let person = createPerson(from: contact)
                modelContext.insert(person)
                added += 1
            }

            // Collect relationships for second pass
            for relation in contact.contactRelations {
                relationships.append((contact, relation))
            }
        }

        // Save first to ensure all people exist
        try modelContext.save()

        // Second pass: create relationship records
        let relationshipsCreated = try await processRelationships(
            relationships,
            modelContext: modelContext
        )

        try modelContext.save()

        return SyncResult(
            added: added,
            updated: updated,
            relationshipsCreated: relationshipsCreated,
            total: fetchedContacts.count
        )
    }

    // MARK: - Private Helpers

    private func createPerson(from contact: CNContact) -> Person {
        Person(
            firstName: contact.givenName,
            lastName: contact.familyName,
            phoneNumber: contact.phoneNumbers.first?.value.stringValue,
            email: contact.emailAddresses.first?.value as String?,
            photoData: contact.thumbnailImageData,
            source: .phoneContact,
            contactIdentifier: contact.identifier
        )
    }

    private func updatePerson(_ person: Person, from contact: CNContact) -> Bool {
        var changed = false

        if person.firstName != contact.givenName {
            person.firstName = contact.givenName
            changed = true
        }
        if person.lastName != contact.familyName {
            person.lastName = contact.familyName
            changed = true
        }
        if person.phoneNumber != contact.phoneNumbers.first?.value.stringValue {
            person.phoneNumber = contact.phoneNumbers.first?.value.stringValue
            changed = true
        }
        if person.email != (contact.emailAddresses.first?.value as String?) {
            person.email = contact.emailAddresses.first?.value as String?
            changed = true
        }
        if person.photoData != contact.thumbnailImageData {
            person.photoData = contact.thumbnailImageData
            changed = true
        }

        if changed {
            person.updatedAt = Date()
        }

        return changed
    }

    @MainActor
    private func processRelationships(
        _ relationships: [(CNContact, CNLabeledValue<CNContactRelation>)],
        modelContext: ModelContext
    ) async throws -> Int {
        var created = 0

        for (contact, labeledRelation) in relationships {
            let relatedName = labeledRelation.value.name
            let relationshipType = parseRelationshipLabel(labeledRelation.label)

            // Find the person for this contact
            guard let person = try findPerson(
                byContactIdentifier: contact.identifier,
                modelContext: modelContext
            ) else { continue }

            // Try to find the related person by name
            guard let relatedPerson = try findPerson(
                byName: relatedName,
                modelContext: modelContext
            ) else { continue }

            // Check if relationship already exists
            let existingRelationship = person.relationships.first { rel in
                rel.relatedPerson?.id == relatedPerson.id &&
                rel.relationshipType == relationshipType
            }

            if existingRelationship == nil {
                let relationship = PersonRelationship(
                    person: person,
                    relatedPerson: relatedPerson,
                    relationshipType: relationshipType,
                    source: .phoneContacts
                )
                modelContext.insert(relationship)
                created += 1
            }
        }

        return created
    }

    @MainActor
    private func findPerson(
        byContactIdentifier identifier: String,
        modelContext: ModelContext
    ) throws -> Person? {
        let descriptor = FetchDescriptor<Person>(
            predicate: #Predicate { $0.contactIdentifier == identifier }
        )
        return try modelContext.fetch(descriptor).first
    }

    @MainActor
    private func findPerson(
        byName name: String,
        modelContext: ModelContext
    ) throws -> Person? {
        let components = name.split(separator: " ", maxSplits: 1)
        let firstName = String(components.first ?? "")
        let lastName = components.count > 1 ? String(components[1]) : ""

        let descriptor = FetchDescriptor<Person>(
            predicate: #Predicate { person in
                person.firstName == firstName && person.lastName == lastName
            }
        )

        if let exact = try modelContext.fetch(descriptor).first {
            return exact
        }

        // Try first name only match
        let firstNameDescriptor = FetchDescriptor<Person>(
            predicate: #Predicate { person in
                person.firstName == firstName
            }
        )
        return try modelContext.fetch(firstNameDescriptor).first
    }

    private func parseRelationshipLabel(_ label: String?) -> String {
        guard let label = label else { return "related" }

        // CNContact relationship labels are like "_$!<Spouse>!$_"
        let cleanLabel = label
            .replacingOccurrences(of: "_$!<", with: "")
            .replacingOccurrences(of: ">!$_", with: "")
            .lowercased()

        switch cleanLabel {
        case "spouse", "husband", "wife": return "spouse"
        case "child", "son", "daughter": return "child"
        case "parent", "mother", "father": return "parent"
        case "brother", "sister", "sibling": return "sibling"
        case "friend": return "friend"
        case "partner": return "partner"
        case "manager": return "manager"
        case "assistant": return "assistant"
        default: return cleanLabel.isEmpty ? "related" : cleanLabel
        }
    }
}

// MARK: - Types

struct SyncResult {
    let added: Int
    let updated: Int
    let relationshipsCreated: Int
    let total: Int

    var description: String {
        if added == 0 && updated == 0 {
            return "Contacts are up to date"
        }
        var parts: [String] = []
        if added > 0 { parts.append("\(added) added") }
        if updated > 0 { parts.append("\(updated) updated") }
        if relationshipsCreated > 0 { parts.append("\(relationshipsCreated) relationships") }
        return parts.joined(separator: ", ")
    }
}

enum ContactSyncError: LocalizedError {
    case notAuthorized
    case syncFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Contact access not authorized. Please enable in Settings."
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        }
    }
}
