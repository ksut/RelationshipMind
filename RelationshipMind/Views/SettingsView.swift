import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("needsAttentionDays") private var needsAttentionDays: Int = 30
    @AppStorage("useWhatsApp") private var useWhatsApp: Bool = false
    @State private var apiKey: String = ""
    @State private var showingAPIKey = false
    @State private var saveStatus: SaveStatus?
    @State private var isTesting = false
    @State private var testResult: TestResult?

    enum SaveStatus {
        case saved
        case cleared
    }

    enum TestResult {
        case success
        case error(String)
    }

    var hasExistingKey: Bool {
        KeychainHelper.hasKey(.claudeAPIKey)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Claude API Key")
                            .font(.headline)

                        if hasExistingKey && apiKey.isEmpty {
                            HStack {
                                Text(showingAPIKey ? (KeychainHelper.get(.claudeAPIKey) ?? "") : "••••••••••••••••")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)

                                Spacer()

                                Button {
                                    showingAPIKey.toggle()
                                } label: {
                                    Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        SecureField("Enter API Key", text: $apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Text("Get your API key from console.anthropic.com")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    if let status = saveStatus {
                        HStack {
                            Image(systemName: status == .saved ? "checkmark.circle.fill" : "trash.circle.fill")
                            Text(status == .saved ? "API key saved" : "API key cleared")
                        }
                        .foregroundColor(status == .saved ? .green : .orange)
                        .font(.caption)
                    }
                }

                Section {
                    Button("Save API Key") {
                        saveAPIKey()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                    if hasExistingKey {
                        Button {
                            testAPIKey()
                        } label: {
                            HStack {
                                Text("Test API Key")
                                Spacer()
                                if isTesting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                }
                            }
                        }
                        .disabled(isTesting)

                        Button("Clear API Key", role: .destructive) {
                            clearAPIKey()
                        }
                    }
                } footer: {
                    if let result = testResult {
                        HStack {
                            switch result {
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("API key is valid!")
                                    .foregroundColor(.green)
                            case .error(let message):
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(message)
                                    .foregroundColor(.red)
                            }
                        }
                        .font(.caption)
                    }
                }

                Section("Preferences") {
                    VStack(alignment: .leading, spacing: 8) {
                        Stepper("Needs Attention: \(needsAttentionDays) days", value: $needsAttentionDays, in: 7...180, step: 7)
                        Text("People with no interactions for this many days will appear in the \"Needs Attention\" section on the home screen.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    Toggle(isOn: $useWhatsApp) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use WhatsApp for messaging")
                            Text("The Message button on contacts will open WhatsApp instead of iMessage.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("AI Model", value: "Claude Sonnet")

                    VStack(alignment: .leading, spacing: 4) {
                        Text("How it works")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("When you log an interaction, the note is sent to Claude AI to extract facts about people mentioned. All data is stored locally on your device.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Privacy") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your data stays on-device")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Only the note text is sent to Claude API for extraction. Your contacts, facts, and relationship data never leave your device.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveAPIKey() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)
        if KeychainHelper.save(trimmedKey, for: .claudeAPIKey) {
            saveStatus = .saved
            apiKey = ""
            // Auto-hide status after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                saveStatus = nil
            }
        }
    }

    private func clearAPIKey() {
        KeychainHelper.delete(.claudeAPIKey)
        saveStatus = .cleared
        apiKey = ""
        testResult = nil
        // Auto-hide status after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            saveStatus = nil
        }
    }

    private func testAPIKey() {
        isTesting = true
        testResult = nil

        Task {
            do {
                let service = ClaudeAPIService()
                let _ = try await service.extractFromNote(
                    note: "Test message - please respond with a simple JSON.",
                    primaryPersonName: "Test Person"
                )
                await MainActor.run {
                    testResult = .success
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    if let apiError = error as? ClaudeAPIError {
                        testResult = .error(apiError.localizedDescription)
                    } else {
                        testResult = .error(error.localizedDescription)
                    }
                    isTesting = false
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
