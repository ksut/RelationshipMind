# RelationshipMind

A private, AI-powered relationship journal for iPhone. Log interactions with people through voice or text, and the app intelligently extracts, organizes, and evolves structured knowledge about your relationships over time.

## Tech Stack

- **Swift 5.9+** / **SwiftUI** (iOS 17+)
- **SwiftData** — fully local, on-device storage
- **Apple Contacts** — iPhone contact sync
- **Apple Speech** — voice dictation
- **Claude API** — AI-powered fact extraction
- **Face ID / Passcode** — biometric lock

## Build & Run

1. Open `RelationshipMind.xcodeproj` in Xcode 15+
2. Set your development team in Signing & Capabilities
3. Build and run on simulator or physical device
4. On first launch, the onboarding flow will prompt for contacts permission and Claude API key

## App Icon

The app icon is a single 1024x1024 PNG. Xcode generates all smaller sizes automatically.

**To replace the icon:**

1. Design a 1024x1024 PNG in any image editor (Figma, Canva, Sketch, etc.)
2. Save it as `AppIcon.png`
3. Replace the file at: `RelationshipMind/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
4. Rebuild the project

No code changes needed — just swap the image file.

## Project Structure

```
RelationshipMind/
├── RelationshipMindApp.swift        # Entry point, onboarding + biometric gates
├── Models/                          # SwiftData models (Person, Touchpoint, Fact, PersonRelationship)
├── Views/
│   ├── ContentView.swift            # 3-tab navigation (Home, People, Insights)
│   ├── Home/                        # Home screen, touchpoint cards
│   ├── People/                      # People list, person detail, facts panel, timeline
│   ├── Touchpoint/                  # Log interaction, contact picker, dictation, extraction review
│   ├── Onboarding/                  # First-launch walkthrough
│   └── Shared/                      # Avatar, lock screen, app icon preview
├── Services/                        # Claude API, contact sync, speech, extraction
└── Utilities/                       # Keychain, fuzzy matcher, haptics
```

## Privacy

All data stays on-device. The only network call is sending note text to the Claude API for fact extraction. No analytics, no cloud sync, no server.
