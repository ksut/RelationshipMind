import Foundation
import SwiftData

enum PersonSource: String, Codable {
    case phoneContact   // synced from iPhone contacts
    case appLocal       // discovered in notes, exists only in app
}

@Model
final class Person {
    var id: UUID
    var firstName: String
    var lastName: String
    var phoneNumber: String?
    var email: String?
    @Attribute(.externalStorage) var photoData: Data?
    var source: PersonSource
    var contactIdentifier: String?  // Apple CNContact identifier for sync
    var createdAt: Date
    var updatedAt: Date

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Touchpoint.primaryPerson)
    var touchpoints: [Touchpoint] = []

    @Relationship(deleteRule: .cascade, inverse: \Fact.person)
    var facts: [Fact] = []

    @Relationship(deleteRule: .cascade, inverse: \PersonRelationship.person)
    var relationships: [PersonRelationship] = []

    // Computed properties
    var displayName: String {
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return fullName.isEmpty ? "Unknown" : fullName
    }

    var lastContactedAt: Date? {
        touchpoints.map { $0.occurredAt }.max()
    }

    var touchpointCount: Int {
        touchpoints.count
    }

    var initials: String {
        let firstInitial = firstName.first.map { String($0) } ?? ""
        let lastInitial = lastName.first.map { String($0) } ?? ""
        let result = "\(firstInitial)\(lastInitial)".uppercased()
        return result.isEmpty ? "?" : result
    }

    init(
        id: UUID = UUID(),
        firstName: String,
        lastName: String = "",
        phoneNumber: String? = nil,
        email: String? = nil,
        photoData: Data? = nil,
        source: PersonSource = .appLocal,
        contactIdentifier: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumber = phoneNumber
        self.email = email
        self.photoData = photoData
        self.source = source
        self.contactIdentifier = contactIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
