import Foundation
import SwiftData

@Observable
final class ExtractionService {
    private let claudeAPI = ClaudeAPIService()

    var isExtracting = false
    var lastError: Error?

    // MARK: - Phase A: Extract (no database writes)

    /// Calls Claude API and returns an ExtractionResult with fuzzy-matched people.
    /// Does NOT write anything to the database.
    func extract(
        touchpoint: Touchpoint,
        modelContext: ModelContext
    ) async throws -> ExtractionResult {
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

            // Fetch all people for fuzzy matching
            let descriptor = FetchDescriptor<Person>()
            let allPeople = try modelContext.fetch(descriptor)

            // Build mentioned people with fuzzy matches
            var mentionedPeople: [ExtractionResult.MentionedPerson] = []

            for mentioned in response.mentionedPeople {
                if mentioned.isPrimary {
                    mentionedPeople.append(ExtractionResult.MentionedPerson(
                        name: mentioned.name,
                        relationshipToPrimary: mentioned.relationshipToPrimary,
                        isPrimary: true,
                        matchedPerson: primaryPerson,
                        fuzzyMatches: [],
                        isConfirmed: true
                    ))
                    continue
                }

                let matches = FuzzyMatcher.findMatches(
                    for: mentioned.name,
                    in: allPeople,
                    threshold: 0.5
                )

                var matchedPerson: Person? = nil
                let fuzzyMatches = matches

                // Auto-select if top match score >= 0.85
                if let top = matches.first, top.score >= 0.85 {
                    matchedPerson = top.person
                }

                mentionedPeople.append(ExtractionResult.MentionedPerson(
                    name: mentioned.name,
                    relationshipToPrimary: mentioned.relationshipToPrimary,
                    isPrimary: false,
                    matchedPerson: matchedPerson,
                    fuzzyMatches: fuzzyMatches,
                    isConfirmed: true
                ))
            }

            // Build extracted facts
            var facts: [ExtractionResult.ExtractedFact] = []
            for factData in response.facts {
                let category = parseCategory(factData.category)
                let timeProgression = parseTimeProgression(factData.timeProgression)
                let factDate = parseDate(factData.factDate)

                facts.append(ExtractionResult.ExtractedFact(
                    personName: factData.personName,
                    category: category,
                    key: factData.key,
                    value: factData.value,
                    factDate: factDate,
                    isTimeSensitive: factData.isTimeSensitive,
                    timeProgression: timeProgression,
                    confidence: factData.confidence,
                    isConfirmed: true
                ))
            }

            return ExtractionResult(
                summary: response.summary,
                mentionedPeople: mentionedPeople,
                facts: facts
            )

        } catch {
            lastError = error
            throw error
        }
    }

    // MARK: - Phase B: Save confirmed extraction results

    /// Writes confirmed people, facts, and relationships to the database.
    /// Handles fact supersession for same category+key on a person.
    func saveExtractionResult(
        _ result: ExtractionResult,
        touchpoint: Touchpoint,
        modelContext: ModelContext
    ) throws {
        guard let primaryPerson = touchpoint.primaryPerson else {
            throw ExtractionError.noPrimaryPerson
        }

        // Update touchpoint summary
        touchpoint.summary = result.summary

        // Process confirmed mentioned people
        for mentioned in result.mentionedPeople where mentioned.isConfirmed && !mentioned.isPrimary {
            let person: Person
            if let matched = mentioned.matchedPerson {
                person = matched
            } else {
                // Create new app-local person
                let components = mentioned.name.split(separator: " ", maxSplits: 1)
                let firstName = String(components.first ?? Substring(mentioned.name))
                let lastName = components.count > 1 ? String(components[1]) : ""
                person = Person(firstName: firstName, lastName: lastName, source: .appLocal)
                modelContext.insert(person)
            }

            // Add to mentioned people if not already there
            if !touchpoint.mentionedPeople.contains(where: { $0.id == person.id }) {
                touchpoint.mentionedPeople.append(person)
            }

            // Create relationship if specified
            if let relationshipType = mentioned.relationshipToPrimary,
               !relationshipType.isEmpty {
                createRelationshipIfNeeded(
                    from: primaryPerson,
                    to: person,
                    type: relationshipType,
                    modelContext: modelContext
                )
            }
        }

        // Process confirmed facts
        for factData in result.facts where factData.isConfirmed {
            // Resolve which person this fact belongs to
            let person = resolvePerson(
                name: factData.personName,
                primaryPerson: primaryPerson,
                mentionedPeople: result.mentionedPeople
            )

            guard let person = person else { continue }

            let newFact = Fact(
                person: person,
                sourceTouchpoint: touchpoint,
                category: factData.category,
                key: factData.key,
                value: factData.value,
                factDate: factData.factDate,
                isTimeSensitive: factData.isTimeSensitive,
                timeProgression: factData.timeProgression,
                confidence: factData.confidence
            )

            // Supersession: check for existing active fact with same category + key
            let existingFact = person.facts.first { f in
                !f.isSuperseded &&
                f.category == factData.category &&
                f.key.lowercased() == factData.key.lowercased() &&
                f.id != newFact.id
            }
            if let existing = existingFact {
                existing.isSuperseded = true
                existing.supersededBy = newFact
            }

            modelContext.insert(newFact)
            person.facts.append(newFact)
            touchpoint.extractedFacts.append(newFact)
        }

        try modelContext.save()
    }

    // MARK: - Backward-compatible wrapper

    /// Calls extract + save in one shot (no review step).
    func extractAndSave(
        touchpoint: Touchpoint,
        modelContext: ModelContext
    ) async throws {
        let result = try await extract(touchpoint: touchpoint, modelContext: modelContext)
        try saveExtractionResult(result, touchpoint: touchpoint, modelContext: modelContext)
    }

    // MARK: - Private Helpers

    private func resolvePerson(
        name: String,
        primaryPerson: Person,
        mentionedPeople: [ExtractionResult.MentionedPerson]
    ) -> Person? {
        // Check if it's the primary person
        if name.lowercased() == primaryPerson.displayName.lowercased() ||
           name.lowercased() == primaryPerson.firstName.lowercased() {
            return primaryPerson
        }

        // Find in confirmed mentioned people
        if let mentioned = mentionedPeople.first(where: {
            $0.isConfirmed &&
            $0.name.lowercased() == name.lowercased()
        }) {
            return mentioned.matchedPerson
        }

        // Fallback: if the fact names the primary person differently, use primary
        return primaryPerson
    }

    private func createRelationshipIfNeeded(
        from person: Person,
        to relatedPerson: Person,
        type: String,
        modelContext: ModelContext
    ) {
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
        case "none": return TimeProgression.none
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
