import SwiftUI
import Contacts

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @State private var currentPage = 0
    @State private var apiKey = ""
    @State private var isSyncing = false
    @State private var contactsGranted = false

    private let contactSyncService = ContactSyncService()

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                privacyPage.tag(1)
                getStartedPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            bottomButton
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
        .onAppear {
            contactsGranted = contactSyncService.isAuthorized
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            Text("RelationshipMind")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your private relationship memory")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("Log conversations naturally. AI extracts and organizes facts about the people in your life.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Page 2: Privacy

    private var privacyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("Privacy First")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 16) {
                privacyRow(icon: "iphone", color: .blue,
                    text: "All data stored locally on your device")
                privacyRow(icon: "icloud.slash", color: .orange,
                    text: "Nothing synced to any cloud server")
                privacyRow(icon: "text.bubble", color: .purple,
                    text: "Only note text sent to AI for extraction")
                privacyRow(icon: "key.fill", color: .green,
                    text: "API key secured in device Keychain")
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func privacyRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)
            Text(text)
                .font(.body)
        }
    }

    // MARK: - Page 3: Get Started

    private var getStartedPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            Text("Get Started")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Contacts permission card
            VStack(alignment: .leading, spacing: 12) {
                Text("Sync Contacts")
                    .font(.headline)

                Text("Import your iPhone contacts to start tracking relationships.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if contactsGranted {
                    Label("Contacts access granted", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                } else {
                    Button("Allow Contacts Access") {
                        requestContacts()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 24)

            // API Key card
            VStack(alignment: .leading, spacing: 12) {
                Text("Claude API Key")
                    .font(.headline)

                Text("Required for AI-powered fact extraction. Get yours at console.anthropic.com")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if KeychainHelper.hasKey(.claudeAPIKey) {
                    Label("API key saved", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                } else {
                    SecureField("sk-ant-...", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button("Save Key") {
                        saveAPIKey()
                    }
                    .buttonStyle(.bordered)
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        Group {
            if currentPage < 2 {
                Button {
                    withAnimation {
                        currentPage += 1
                    }
                } label: {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            } else {
                Button {
                    completeOnboarding()
                } label: {
                    HStack {
                        if isSyncing {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSyncing ? "Setting up..." : "Let's Go!")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isSyncing)
            }
        }
    }

    // MARK: - Actions

    private func requestContacts() {
        Task {
            let granted = await contactSyncService.requestAccess()
            await MainActor.run {
                contactsGranted = granted
                if granted {
                    HapticService.success()
                }
            }
        }
    }

    private func saveAPIKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        if KeychainHelper.save(trimmed, for: .claudeAPIKey) {
            apiKey = ""
            HapticService.success()
        }
    }

    private func completeOnboarding() {
        isSyncing = true

        Task {
            if contactSyncService.isAuthorized {
                do {
                    let _ = try await contactSyncService.syncContacts(modelContext: modelContext)
                } catch {
                    print("Initial sync failed: \(error)")
                }
            }

            await MainActor.run {
                isSyncing = false
                HapticService.success()
                hasCompletedOnboarding = true
            }
        }
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [Person.self, Touchpoint.self, Fact.self, PersonRelationship.self], inMemory: true)
}
