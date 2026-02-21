# RelationshipMind — Getting Started Guide

## What This Is
Everything you need to start building RelationshipMind with Claude Code tonight.

## Prerequisites Checklist

### ✅ You Already Have
- [x] MacBook Pro
- [x] Anthropic API access (for Claude API in the app)

### 📥 Install These Before Starting

**1. Xcode (Free)**
- Open Mac App Store → Search "Xcode" → Install
- It's ~12GB so start this download first
- After install, open Xcode once to accept the license and install components
- Verify: `xcode-select --version` in Terminal

**2. Claude Code (CLI)**
- Open Terminal and run: `npm install -g @anthropic-ai/claude-code`
- If you don't have npm/Node.js: `brew install node` first
- If you don't have Homebrew: visit https://brew.sh
- Verify: `claude --version` in Terminal

**3. Apple Developer Account ($99/year)**
- Go to https://developer.apple.com/account
- You need this for: testing on your real iPhone, App Store submission
- You can START building without it (simulator works), but get it soon
- Sign up with your Apple ID

**4. Git (likely already installed)**
- Verify: `git --version` in Terminal
- If not installed, Xcode install typically includes it

## Setup Steps

### Step 1: Create Project Folder
```bash
mkdir -p ~/Projects/RelationshipMind
cp /path/to/downloaded/CLAUDE.md ~/Projects/RelationshipMind/
```

### Step 2: Open Claude Code
```bash
cd ~/Projects/RelationshipMind
claude
```

### Step 3: Give Claude Code the Initial Instruction
Paste this as your first message in Claude Code:

---

Read the CLAUDE.md file in this directory. This is the full specification for an iPhone app called RelationshipMind. Please:

1. Create a new Xcode project for an iOS app using SwiftUI and SwiftData
2. Set up the complete file structure as defined in CLAUDE.md
3. Implement the SwiftData models (Person, Touchpoint, Fact, PersonRelationship)
4. Create the basic TabView navigation with Home, People, and Insights tabs
5. Build the People list view with search functionality
6. Set up the ContactSyncService to import iPhone contacts

Start with steps 1-4 and show me what you've built before moving on.

---

### Step 4: Iterate From There
Claude Code will generate the Xcode project and initial code. From there you'll work through the phases defined in CLAUDE.md, asking Claude Code to build each piece.

## API Key Setup
Your Claude API key (for the app's AI extraction feature) will be entered by the user in the app's Settings screen and stored securely in iOS Keychain. You do NOT hardcode it.

For Claude Code itself, it uses your existing `ANTHROPIC_API_KEY` environment variable.

## Useful Claude Code Commands
- `claude` — Start Claude Code in current directory
- Talk naturally: "Build the contact picker view" or "Fix the bug in PersonDetailView"
- Claude Code can read, write, and run code directly
- It can also run `xcodebuild` to compile and catch errors

## Notes for a Swift Beginner
- SwiftUI uses declarative syntax — you describe WHAT the UI looks like, not HOW to build it
- `@Model` is SwiftData's way of marking a class as a database table
- `@State`, `@Binding`, `@Observable` are how SwiftUI manages data flow
- Don't worry about memorizing syntax — Claude Code will write it and you'll learn by reading
- The Xcode preview canvas (right side) shows your UI live as you code
- Cmd+R in Xcode builds and runs the app in the simulator

## Project Timeline Reference
- Phase 1 (Week 1-2): Foundation — models, contact sync, people list
- Phase 2 (Week 3-4): Core capture — touchpoint logging, Claude API, extraction
- Phase 3 (Week 5-6): Voice & intelligence — dictation, fuzzy matching, fact evolution
- Phase 4 (Week 7-8): Home screen, analytics, timeline
- Phase 5 (Week 9-10): Polish, onboarding, App Store submission
