import Foundation
import SwiftData

@Observable
final class ExtractionService {
    private let claudeAPI = ClaudeAPIService()

    var isExtracting = false
    var lastError: Error?

    func extractAndSave(
        touchpoint: Touchpoint,
        modelContext: ModelContext
    ) async throws {
        guard let primaryPerson = touchpoint.primaryPerson else {
            throw ExtractionError.noPrimaryPerson
        }

        isExtracting = true
        lastError = nil

        defer { isExtracting = false }

        do {
            let response = try await claudeAPI.extractFromNote(
                note: touchpoint.rawNote,
                primaryPersonName: primaryPerson.displayName
            )

            // Update touchpoint summary
            touchpoint.summary = response.summary

            // Process mentioned people
            for mentionedPerson in response.mentionedPeople {
                if !mentionedPerson.isPrimary {
                    // Try to find existing person or create new one
                    let person = try findOrCreatePerson(
                        name: mentionedPerson.name,
                        modelContext: modelContext
                    )

                    // Add to mentioned people if not already there
                    if !touchpoint.mentionedPeople.contains(where: { $0.id == person.id }) {
                        touchpoint.mentionedPeople.append(person)
                    }

                    // Create relationship if specified
                    if let relationshipType = mentionedPerson.relationshipToPrimary,
                       !relationshipType.isEmpty {
                        createRelationshipIfNeeded(
                            from: primaryPerson,
                            to: person,
                            type: relationshipType,
                            modelContext: modelContext
                        )
                    }
                }
            }

            // Process extracted facts
            for factData in response.facts {
                let person = try findPerson(
                    name: factData.personName,
                    primaryPerson: primaryPerson,
                    modelContext: modelContext
                )

                guard let person = person else { continue }

                let category = parseCategory(factData.category)
                let timeProgression = parseTimeProgression(factData.timeProgression)
                let factDate = parseDate(factData.factDate)

                let fact = Fact(
                    person: person,
                    sourceTouchpoint: touchpoint,
                    category: category,
                    key: factData.key,
                    value: factData.value,
                    factDate: factDate,
                    isTimeSensitive: factData.isTimeSensitive,
                    timeProgression: timeProgression,
                    confidence: factData.confidence
                )

                modelContext.insert(fact)
                person.facts.append(fact)
                touchpoint.extractedFacts.append(fact)
                print("Extracted fact: \(factData.key) = \(factData.value) for \(person.displayName)")
            }

            try modelContext.save()

        } catch {
            lastError = error
            throw error
        }
    }

    // MARK: - Private Helpers

    private func findOrCreatePerson(
        name: String,
        modelContext: ModelContext
    ) throws -> Person {
        // Try to find existing person
        if let existing = try findPersonByName(name, modelContext: modelContext) {
            return existing
        }

        // Create new app-local person
        let components = name.split(separator: " ", maxSplits: 1)
        let firstName = String(components.first ?? Substring(name))
        let lastName = components.count > 1 ? String(components[1]) : ""

        let person = Person(
            firstName: firstName,
            lastName: lastName,
            source: .appLocal
        )
        modelContext.insert(person)
        return person
    }

    private func findPerson(
        name: String,
        primaryPerson: Person,
        modelContext: ModelContext
    ) throws -> Person? {
        // Check if it's the primary person
        if name.lowercased() == primaryPerson.displayName.lowercased() ||
           name.lowercased() == primaryPerson.firstName.lowercased() {
            return primaryPerson
        }

        return try findPersonByName(name, modelContext: modelContext)
    }

    private func findPersonByName(
        _ name: String,
        modelContext: ModelContext
    ) throws -> Person? {
        let components = name.split(separator: " ", maxSplits: 1)
        let firstName = String(components.first ?? "")
        let lastName = components.count > 1 ? String(components[1]) : ""

        // Fetch all and filter (SwiftData predicate limitations)
        let descriptor = FetchDescriptor<Person>()
        let allPeople = try modelContext.fetch(descriptor)

        // Try exact match first
        if let exact = allPeople.first(where: {
            $0.firstName.lowercased() == firstName.lowercased() &&
            $0.lastName.lowercased() == lastName.lowercased()
        }) {
            return exact
        }

        // Try first name match
        if let firstNameMatch = allPeople.first(where: {
            $0.firstName.lowercased() == firstName.lowercased()
        }) {
            return firstNameMatch
        }

        return nil
    }

    private func createRelationshipIfNeeded(
        from person: Person,
        to relatedPerson: Person,
        type: String,
        modelContext: ModelContext
    ) {
        // Check if relationship already exists
        let existingRelationship = person.relationships.first { rel in
            rel.relatedPerson?.id == relatedPerson.id
        }

        if existingRelationship == nil {
            let relationship = PersonRelationship(
                person: person,
                relatedPerson: relatedPerson,
                relationshipType: type.lowercased(),
                source: .extracted
            )
            modelContext.insert(relationship)
        }
    }

    private func parseCategory(_ string: String) -> FactCategory {
        switch string.lowercased() {
        case "education": return .education
        case "career": return .career
        case "family": return .family
        case "health": return .health
        case "location": return .location
        case "travel": return .travel
        case "interest": return .interest
        case "milestone": return .milestone
        case "plan": return .plan
        default: return .general
        }
    }

    private func parseTimeProgression(_ string: String?) -> TimeProgression? {
        guard let string = string else { return nil }
        switch string.lowercased() {
        case "academicyear": return .academicYear
        case "age": return .age
        case "tenure": return .tenure
        case "none": return .none
        default: return nil
        }
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string = string, !string.isEmpty, string != "null" else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}

enum ExtractionError: LocalizedError {
    case noPrimaryPerson

    var errorDescription: String? {
        switch self {
        case .noPrimaryPerson:
            return "No primary person associated with this touchpoint."
        }
    }
}
