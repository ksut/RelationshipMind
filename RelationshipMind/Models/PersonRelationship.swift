import Foundation
import SwiftData

enum RelationshipSource: String, Codable {
    case phoneContacts   // imported from iPhone contact relationships
    case extracted       // discovered from note extraction
    case manual          // user manually set it
}

@Model
final class PersonRelationship {
    var id: UUID
    var person: Person?              // one side
    var relatedPerson: Person?       // other side
    var relationshipType: String     // "daughter", "colleague", "brother", etc.
    var source: RelationshipSource
    var createdAt: Date

    init(
        id: UUID = UUID(),
        person: Person? = nil,
        relatedPerson: Person? = nil,
        relationshipType: String,
        source: RelationshipSource = .manual,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.person = person
        self.relatedPerson = relatedPerson
        self.relationshipType = relationshipType
        self.source = source
        self.createdAt = createdAt
    }
}
