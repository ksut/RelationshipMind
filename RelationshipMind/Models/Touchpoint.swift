import Foundation
import SwiftData

enum InteractionType: String, Codable, CaseIterable {
    case phoneCall = "Phone Call"
    case inPerson = "In Person"
    case text = "Text"
    case video = "Video"
    case social = "Social Media"
    case email = "Email"
    case whatsapp = "WhatsApp"
    case other = "Other"

    var icon: String {
        switch self {
        case .phoneCall: return "phone.fill"
        case .inPerson: return "person.2.fill"
        case .text: return "message.fill"
        case .video: return "video.fill"
        case .social: return "globe"
        case .email: return "envelope.fill"
        case .whatsapp: return "bubble.left.and.text.bubble.right.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

@Model
final class Touchpoint {
    var id: UUID
    var rawNote: String               // original dictated/typed text
    var summary: String?              // AI-generated short summary
    var interactionType: InteractionType
    var occurredAt: Date              // when the interaction happened
    var createdAt: Date               // when the note was logged

    // Relationships
    var primaryPerson: Person?

    @Relationship
    var mentionedPeople: [Person] = []

    @Relationship(deleteRule: .cascade, inverse: \Fact.sourceTouchpoint)
    var extractedFacts: [Fact] = []

    init(
        id: UUID = UUID(),
        rawNote: String,
        summary: String? = nil,
        interactionType: InteractionType = .other,
        occurredAt: Date = Date(),
        createdAt: Date = Date(),
        primaryPerson: Person? = nil
    ) {
        self.id = id
        self.rawNote = rawNote
        self.summary = summary
        self.interactionType = interactionType
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.primaryPerson = primaryPerson
    }
}
