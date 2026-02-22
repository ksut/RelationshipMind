import SwiftUI
import SwiftData
import LocalAuthentication

@main
struct RelationshipMindApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked: Bool

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Person.self,
            Touchpoint.self,
            Fact.self,
            PersonRelationship.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        _isLocked = State(initialValue: UserDefaults.standard.bool(forKey: "biometricLockEnabled"))
    }

    private func authenticateOnActive() {
        let context = LAContext()
        context.localizedCancelTitle = "Use Passcode"
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock RelationshipMind") { success, _ in
            DispatchQueue.main.async {
                if success {
                    HapticService.success()
                    isLocked = false
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !hasCompletedOnboarding {
                    OnboardingView()
                } else {
                    ContentView()
                }

                if hasCompletedOnboarding && biometricLockEnabled && isLocked {
                    LockScreenView {
                        isLocked = false
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isLocked)
            .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if biometricLockEnabled && hasCompletedOnboarding {
                if newPhase == .background {
                    isLocked = true
                } else if newPhase == .active && isLocked {
                    authenticateOnActive()
                }
            }
        }
    }
}
