# RelationshipMind - AI-Powered Relationship Journal

## Project Overview
A private, AI-powered relationship journal for iPhone. Single-user, fully local data storage, no social features. Users log interactions with people through voice or text, and the app intelligently extracts, organizes, and evolves structured knowledge about relationships over time.

**This is NOT a CRM or social network.** It is a personal memory system — a private journal organized around people instead of dates.

## Tech Stack
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (iOS 17+)
- **Database:** SwiftData (fully local, on-device)
- **Contacts:** Apple Contacts framework (CNContact)
- **Voice Input:** Apple Speech framework (SFSpeechRecognizer)
- **AI Extraction:** Anthropic Claude API (claude-sonnet-4-20250514)
- **Authentication:** Face ID / Device Passcode only (no server auth)
- **Backend:** None. Fully local app. Only network call is to Claude API for note extraction.
- **Architecture:** MVVM (Model-View-ViewModel)

## Design Principles
1. **Privacy first** — All data stored on-device via SwiftData. Nothing synced to any server. Claude API receives only the note text for extraction, nothing else.
2. **Minimum taps to capture** — Voice dictation should be accessible within 1 tap from app launch.
3. **AI does the heavy lifting** — User speaks naturally, AI extracts structured facts. User reviews and confirms.
4. **Contacts are source of truth** — iPhone contact book is the primary people source. App-local contacts are secondary, created only when new names appear in notes.
5. **Time-aware facts** — Facts are stored with timestamps. The system computes current state from historical data (e.g., "started college Fall 2026" → "in 2nd year" by Fall 2027).
6. **Native iOS look and feel** — Use standard Apple components. No custom design system needed for v1.

## Data Model (SwiftData)

### Person
The unified model for all people in the app.
```
@Model
class Person {
    var id: UUID
    var firstName: String
    var lastName: String
    var phoneNumber: String?          // nil for app-local contacts
    var email: String?
    var photoData: Data?              // thumbnail from contacts
    var source: PersonSource          // .phoneContact or .appLocal
    var contactIdentifier: String?    // Apple CNContact identifier for sync
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    var touchpoints: [Touchpoint]
    var facts: [Fact]
    var relationships: [PersonRelationship]
    
    // Computed
    var displayName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
    var lastContactedAt: Date?        // derived from most recent touchpoint
    var touchpointCount: Int          // derived
}

enum PersonSource: String, Codable {
    case phoneContact   // synced from iPhone contacts
    case appLocal       // discovered in notes, exists only in app
}
```

### Touchpoint
A single logged interaction (conversation, meeting, call, etc.)
```
@Model
class Touchpoint {
    var id: UUID
    var rawNote: String               // original dictated/typed text
    var summary: String?              // AI-generated short summary
    var interactionType: InteractionType
    var occurredAt: Date              // when the interaction happened
    var createdAt: Date               // when the note was logged
    
    // Relationships
    var primaryPerson: Person         // who you selected before dictating
    var mentionedPeople: [Person]     // other people mentioned in the note
    var extractedFacts: [Fact]        // facts pulled from this touchpoint
}

enum InteractionType: String, Codable {
    case phoneCall
    case inPerson
    case text
    case video
    case social      // social media interaction
    case other
}
```

### Fact
A structured piece of knowledge extracted from a touchpoint.
```
@Model
class Fact {
    var id: UUID
    var person: Person                // who this fact is about
    var sourceTouchpoint: Touchpoint  // where it was extracted from
    var category: FactCategory
    var key: String                   // e.g., "college", "job_title", "child_grade"
    var value: String                 // e.g., "Engineering at IIT Delhi"
    var factDate: Date?               // when this fact became true (if known)
    var isTimeSensitive: Bool         // does this fact evolve over time?
    var timeProgression: TimeProgression? // how to compute current state
    var isSuperseded: Bool            // has a newer fact replaced this?
    var supersededBy: Fact?
    var extractedAt: Date
    var confidence: Double            // AI confidence score 0.0-1.0
}

enum FactCategory: String, Codable {
    case education       // school, college, grade level
    case career          // job, company, role
    case family          // marriage, children, family events
    case health          // health updates
    case location        // where they live, moving plans
    case travel          // upcoming or past trips
    case interest        // hobbies, interests
    case milestone       // birthdays, anniversaries, achievements
    case plan            // future plans mentioned
    case general         // anything else
}

enum TimeProgression: String, Codable {
    case academicYear    // increments each year (grade/college year)
    case age             // increments each year from birthday
    case tenure          // time at job/company
    case none            // static fact
}
```

### PersonRelationship
Links between people (family, colleagues, friends, etc.)
```
@Model
class PersonRelationship {
    var id: UUID
    var person: Person               // one side
    var relatedPerson: Person        // other side
    var relationshipType: String     // "daughter", "colleague", "brother", etc.
    var source: RelationshipSource
    var createdAt: Date
}

enum RelationshipSource: String, Codable {
    case phoneContacts   // imported from iPhone contact relationships
    case extracted       // discovered from note extraction
    case manual          // user manually set it
}
```

## Core User Flows

### Flow 1: First Launch
1. Welcome screen explaining the app concept
2. Request contacts permission
3. Sync all iPhone contacts (names, phones, emails, photos, relationship labels)
4. Import relationship labels as PersonRelationship records
5. All contacts marked as "dormant" — no touchpoints yet
6. Land on home screen

### Flow 2: Log a Touchpoint (Primary Flow)
1. User taps "+" or big record button on home screen
2. User picks a contact from searchable contacts list (synced contacts)
3. User picks interaction type (phone call, in person, etc.)
4. User dictates or types their note freely
5. App sends note to Claude API for extraction
6. AI returns: summary, mentioned people (with fuzzy match suggestions), extracted facts
7. User sees extraction review card:
   - Summary of the note
   - People mentioned → matched to contacts or flagged as new app-local contacts
   - Facts extracted → each shown with category and value
8. User confirms, edits, or dismisses individual extractions
9. Touchpoint saved locally with all linked data

### Flow 3: View a Person's Profile
1. User taps on a person from contacts list or search
2. Profile shows:
   - Contact info (if synced contact)
   - Relationship labels
   - **Current Facts Panel** — computed current state of all active facts
   - **Timeline** — chronological list of all touchpoints involving this person
   - **Connected People** — other people linked through relationships or co-mentioned in notes
3. Facts show computed current values (e.g., "2nd year, Engineering" not "started college 2026")

### Flow 4: Browse & Discover (Home Screen)
1. **Recent Touchpoints** — latest logged interactions
2. **Needs Attention** — people you haven't contacted in a while (configurable threshold)
3. **Quick Capture** — prominent button to start logging immediately
4. **Search** — search across people, notes, and facts

## Claude API Integration

### Extraction Prompt Structure
When a user saves a note, send to Claude API:
```
System: You are an AI assistant that extracts structured relationship data from personal conversation notes. Extract the following:
1. A brief summary (1-2 sentences)
2. People mentioned (with relationship context if stated)
3. Structured facts about each person mentioned
4. Any time-sensitive information with approximate dates

The primary person this note is about: {person_name}
Today's date: {current_date}

Return JSON in this exact format:
{
  "summary": "...",
  "mentioned_people": [
    {
      "name": "...",
      "relationship_to_primary": "...",  // e.g., "daughter", "colleague"
      "is_primary": true/false
    }
  ],
  "facts": [
    {
      "person_name": "...",
      "category": "education|career|family|health|location|travel|interest|milestone|plan|general",
      "key": "...",
      "value": "...",
      "fact_date": "YYYY-MM-DD or null",
      "is_time_sensitive": true/false,
      "time_progression": "academicYear|age|tenure|none",
      "confidence": 0.0-1.0
    }
  ]
}

User note: {raw_note_text}
```

### API Configuration
- Model: claude-sonnet-4-20250514 (best balance of speed/cost/quality for extraction)
- Max tokens: 1024 (extractions are concise)
- Temperature: 0 (we want deterministic structured output)
- API key stored in iOS Keychain (never hardcoded)

## Screen Map (Navigation)

```
TabView (3 tabs)
├── Home Tab
│   ├── Home Screen (recent touchpoints, needs attention, quick capture)
│   └── → Log Touchpoint Flow (sheet)
│       ├── Select Contact
│       ├── Select Interaction Type
│       ├── Dictate/Type Note
│       └── Review Extraction
├── People Tab
│   ├── People List (search, filter by synced/app-local)
│   └── → Person Detail
│       ├── Current Facts Panel
│       ├── Timeline
│       └── Connected People
└── Insights Tab (v2)
    ├── Relationship Analytics
    ├── Contact Frequency
    └── Relationship Strength Trends
```

## File Structure
```
RelationshipMind/
├── RelationshipMindApp.swift          # App entry point
├── Info.plist                          # Permissions declarations
├── Models/
│   ├── Person.swift
│   ├── Touchpoint.swift
│   ├── Fact.swift
│   └── PersonRelationship.swift
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── PeopleViewModel.swift
│   ├── PersonDetailViewModel.swift
│   ├── TouchpointViewModel.swift
│   └── ContactSyncViewModel.swift
├── Views/
│   ├── ContentView.swift              # TabView root
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── TouchpointCardView.swift
│   ├── People/
│   │   ├── PeopleListView.swift
│   │   ├── PersonDetailView.swift
│   │   ├── FactsPanel.swift
│   │   └── TimelineView.swift
│   ├── Touchpoint/
│   │   ├── LogTouchpointView.swift
│   │   ├── ContactPickerView.swift
│   │   ├── DictationView.swift
│   │   └── ExtractionReviewView.swift
│   └── Shared/
│       ├── PersonAvatarView.swift
│       └── SearchBarView.swift
├── Services/
│   ├── ClaudeAPIService.swift         # API calls to Claude
│   ├── ContactSyncService.swift       # iPhone contacts sync
│   ├── SpeechService.swift            # Voice dictation
│   ├── ExtractionService.swift        # Orchestrates AI extraction
│   └── FactComputeService.swift       # Time-based fact computation
└── Utilities/
    ├── KeychainHelper.swift           # Secure API key storage
    ├── FuzzyMatcher.swift             # Name matching logic
    └── DateHelper.swift               # Date computation utilities
```

## iOS Permissions Required (Info.plist)
- `NSContactsUsageDescription` — "RelationshipMind syncs your contacts to help you track relationships."
- `NSSpeechRecognitionUsageDescription` — "RelationshipMind uses speech recognition to transcribe your voice notes."
- `NSMicrophoneUsageDescription` — "RelationshipMind needs microphone access for voice dictation."

## Build & Run
1. Open `RelationshipMind.xcodeproj` in Xcode 15+
2. Set your development team in Signing & Capabilities
3. Add your Claude API key in the app's settings screen (stored in Keychain)
4. Build and run on simulator or physical device (physical device needed for contacts + dictation)

## Development Phases

### Phase 1: Foundation (Week 1-2)
- [ ] Xcode project setup with SwiftData models
- [ ] Contact sync service (import all contacts + relationship labels)
- [ ] People list view with search
- [ ] Person detail view (basic)

### Phase 2: Core Capture (Week 3-4)
- [ ] Log touchpoint flow (contact picker → type selector → text input)
- [ ] Claude API integration for extraction
- [ ] Extraction review card UI
- [ ] Save touchpoint with linked facts and people

### Phase 3: Voice & Intelligence (Week 5-6)
- [ ] Voice dictation integration
- [ ] Fuzzy name matching for mentioned people
- [ ] App-local contact creation flow
- [ ] Fact evolution computation (time-sensitive facts)

### Phase 4: Home & Analytics (Week 7-8)
- [ ] Home screen with recent touchpoints
- [ ] "Needs attention" algorithm
- [ ] Person timeline view
- [ ] Connected people view
- [ ] Fact conflict detection

### Phase 5: Polish & App Store (Week 9-10)
- [ ] Onboarding flow
- [ ] Settings screen (API key input, contact frequency thresholds)
- [ ] App icon and branding
- [ ] App Store screenshots and description
- [ ] TestFlight beta → App Store submission

## Key Implementation Notes

### Fuzzy Name Matching
When AI extracts a name like "Priya" from a note, match against contacts using:
1. Exact match on first name
2. Phonetic similarity (Soundex or Levenshtein distance) — catches "Prayer" vs "Priya"
3. Existing app-local contacts
4. If multiple matches, show picker. If single match, show confirmation. If no match, prompt to create app-local contact.

### Fact Time Computation
```swift
func computeCurrentValue(fact: Fact, asOf: Date = .now) -> String {
    guard fact.isTimeSensitive, let factDate = fact.factDate else {
        return fact.value
    }
    
    switch fact.timeProgression {
    case .academicYear:
        let yearsPassed = Calendar.current.dateComponents([.year], from: factDate, to: asOf).year ?? 0
        // "1st year Engineering" + 1 year = "2nd year Engineering"
        return incrementAcademicYear(fact.value, by: yearsPassed)
    case .age:
        let yearsPassed = Calendar.current.dateComponents([.year], from: factDate, to: asOf).year ?? 0
        return "\(Int(fact.value)! + yearsPassed)"
    case .tenure:
        let components = Calendar.current.dateComponents([.year, .month], from: factDate, to: asOf)
        return "\(components.year ?? 0) years, \(components.month ?? 0) months"
    case .none, .none:
        return fact.value
    }
}
```

### Contact Sync Strategy
- On first launch: full import of all contacts
- On subsequent opens: differential sync using CNContactStore change notifications
- Never write back to iPhone contacts — read-only sync
- Store `contactIdentifier` to maintain link between Person and CNContact
