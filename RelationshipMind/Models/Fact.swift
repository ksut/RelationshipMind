import Foundation
import SwiftData

enum FactCategory: String, Codable, CaseIterable {
    case education = "Education"
    case career = "Career"
    case family = "Family"
    case health = "Health"
    case location = "Location"
    case travel = "Travel"
    case interest = "Interest"
    case milestone = "Milestone"
    case plan = "Plan"
    case general = "General"

    var icon: String {
        switch self {
        case .education: return "graduationcap.fill"
        case .career: return "briefcase.fill"
        case .family: return "figure.2.and.child.holdinghands"
        case .health: return "heart.fill"
        case .location: return "location.fill"
        case .travel: return "airplane"
        case .interest: return "star.fill"
        case .milestone: return "flag.fill"
        case .plan: return "calendar"
        case .general: return "info.circle.fill"
        }
    }
}

enum TimeProgression: String, Codable {
    case academicYear   // increments each year (grade/college year)
    case age            // increments each year from birthday
    case tenure         // time at job/company
    case none           // static fact
}

@Model
final class Fact {
    var id: UUID
    var person: Person?
    var sourceTouchpoint: Touchpoint?
    var category: FactCategory
    var key: String                   // e.g., "college", "job_title", "child_grade"
    var value: String                 // e.g., "Engineering at IIT Delhi"
    var factDate: Date?               // when this fact became true (if known)
    var isTimeSensitive: Bool         // does this fact evolve over time?
    var timeProgression: TimeProgression?
    var isSuperseded: Bool            // has a newer fact replaced this?
    var supersededBy: Fact?
    var extractedAt: Date
    var confidence: Double            // AI confidence score 0.0-1.0

    init(
        id: UUID = UUID(),
        person: Person? = nil,
        sourceTouchpoint: Touchpoint? = nil,
        category: FactCategory = .general,
        key: String,
        value: String,
        factDate: Date? = nil,
        isTimeSensitive: Bool = false,
        timeProgression: TimeProgression? = nil,
        isSuperseded: Bool = false,
        supersededBy: Fact? = nil,
        extractedAt: Date = Date(),
        confidence: Double = 1.0
    ) {
        self.id = id
        self.person = person
        self.sourceTouchpoint = sourceTouchpoint
        self.category = category
        self.key = key
        self.value = value
        self.factDate = factDate
        self.isTimeSensitive = isTimeSensitive
        self.timeProgression = timeProgression
        self.isSuperseded = isSuperseded
        self.supersededBy = supersededBy
        self.extractedAt = extractedAt
        self.confidence = confidence
    }

    /// Computes the current value of this fact based on time progression
    func computeCurrentValue(asOf date: Date = .now) -> String {
        guard isTimeSensitive, let factDate = factDate, let progression = timeProgression else {
            return value
        }

        let calendar = Calendar.current

        switch progression {
        case .academicYear:
            let yearsPassed = calendar.dateComponents([.year], from: factDate, to: date).year ?? 0
            return incrementAcademicYear(value, by: yearsPassed)
        case .age:
            let yearsPassed = calendar.dateComponents([.year], from: factDate, to: date).year ?? 0
            if let currentAge = Int(value) {
                return "\(currentAge + yearsPassed)"
            }
            return value
        case .tenure:
            let components = calendar.dateComponents([.year, .month], from: factDate, to: date)
            let years = components.year ?? 0
            let months = components.month ?? 0
            if years > 0 {
                return "\(years) year\(years == 1 ? "" : "s"), \(months) month\(months == 1 ? "" : "s")"
            } else {
                return "\(months) month\(months == 1 ? "" : "s")"
            }
        case .none:
            return value
        }
    }

    private func incrementAcademicYear(_ value: String, by years: Int) -> String {
        // Handle patterns like "1st year Engineering" or "2nd year, Computer Science"
        let ordinals = ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th"]

        for (index, ordinal) in ordinals.enumerated() {
            if value.lowercased().contains(ordinal.lowercased()) {
                let newIndex = min(index + years, ordinals.count - 1)
                let newOrdinal = ordinals[newIndex]
                // Case-insensitive replacement
                if let range = value.range(of: ordinal, options: .caseInsensitive) {
                    return value.replacingCharacters(in: range, with: newOrdinal)
                }
            }
        }

        return value
    }
}
