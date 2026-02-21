import Foundation

enum MatchType: String {
    case exactFullName
    case exactFirstName
    case fuzzyFirstName
    case fuzzyFullName
    case partialLastName
}

struct FuzzyMatch {
    let person: Person
    let score: Double
    let matchType: MatchType
}

struct FuzzyMatcher {

    /// Standard Levenshtein distance between two strings (case-insensitive).
    static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1.lowercased())
        let b = Array(s2.lowercased())
        let n = a.count
        let m = b.count

        if n == 0 { return m }
        if m == 0 { return n }

        // O(n) space — only keep previous and current rows
        var prev = Array(0...m)
        var curr = [Int](repeating: 0, count: m + 1)

        for i in 1...n {
            curr[0] = i
            for j in 1...m {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,        // deletion
                    curr[j - 1] + 1,    // insertion
                    prev[j - 1] + cost  // substitution
                )
            }
            prev = curr
        }

        return prev[m]
    }

    /// Normalized similarity score between 0.0 (completely different) and 1.0 (identical).
    static func similarity(_ s1: String, _ s2: String) -> Double {
        let s1Lower = s1.lowercased().trimmingCharacters(in: .whitespaces)
        let s2Lower = s2.lowercased().trimmingCharacters(in: .whitespaces)

        if s1Lower == s2Lower { return 1.0 }
        if s1Lower.isEmpty || s2Lower.isEmpty { return 0.0 }

        let maxLen = max(s1Lower.count, s2Lower.count)
        let distance = levenshteinDistance(s1Lower, s2Lower)
        return 1.0 - Double(distance) / Double(maxLen)
    }

    /// Find all people matching the given name above the threshold, ranked by score.
    static func findMatches(
        for name: String,
        in people: [Person],
        threshold: Double = 0.5
    ) -> [FuzzyMatch] {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return [] }

        let components = trimmedName.split(separator: " ", maxSplits: 1)
        let queryFirst = String(components.first ?? "")
        let queryLast = components.count > 1 ? String(components[1]) : ""

        var matches: [FuzzyMatch] = []

        for person in people {
            let (score, matchType) = computeScore(
                queryFirst: queryFirst,
                queryLast: queryLast,
                person: person
            )

            if score >= threshold {
                matches.append(FuzzyMatch(
                    person: person,
                    score: score,
                    matchType: matchType
                ))
            }
        }

        return matches.sorted { $0.score > $1.score }
    }

    /// Returns the single best match if it meets the minimum confidence.
    static func bestMatch(
        for name: String,
        in people: [Person],
        minimumConfidence: Double = 0.7
    ) -> FuzzyMatch? {
        let matches = findMatches(for: name, in: people, threshold: minimumConfidence)
        return matches.first
    }

    // MARK: - Private

    private static func computeScore(
        queryFirst: String,
        queryLast: String,
        person: Person
    ) -> (Double, MatchType) {
        let personFirst = person.firstName
        let personLast = person.lastName

        // Exact full name match
        if queryFirst.lowercased() == personFirst.lowercased() &&
           !queryLast.isEmpty &&
           queryLast.lowercased() == personLast.lowercased() {
            return (1.0, .exactFullName)
        }

        // Exact first name match (no last name in query, or last name also matches)
        if queryFirst.lowercased() == personFirst.lowercased() {
            if queryLast.isEmpty {
                // Only first name given, exact match
                return (0.9, .exactFirstName)
            }
            // First name exact, last name partial/fuzzy
            let lastSim = similarity(queryLast, personLast)
            let score = 0.7 + 0.3 * lastSim
            return (score, lastSim >= 0.8 ? .exactFullName : .partialLastName)
        }

        // Fuzzy matching
        let firstSim = similarity(queryFirst, personFirst)

        if queryLast.isEmpty {
            // Only first name given — score based on first name similarity
            let score = firstSim * 0.9
            if score >= 0.5 {
                return (score, .fuzzyFirstName)
            }
            return (score, .fuzzyFirstName)
        }

        // Both first and last name given
        let lastSim = similarity(queryLast, personLast)
        let score = 0.7 * firstSim + 0.3 * lastSim

        let matchType: MatchType
        if firstSim >= 0.8 && lastSim >= 0.8 {
            matchType = .fuzzyFullName
        } else if firstSim >= 0.8 {
            matchType = .fuzzyFirstName
        } else {
            matchType = .fuzzyFullName
        }

        return (score, matchType)
    }
}
