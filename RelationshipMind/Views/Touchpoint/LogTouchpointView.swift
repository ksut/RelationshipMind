import SwiftUI
import SwiftData

struct LogTouchpointView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var preselectedPerson: Person?

    @State private var selectedPerson: Person?
    @State private var interactionType: InteractionType = .inPerson
    @State private var noteText = ""
    @State private var occurredAt = Date()
    @State private var currentStep: LogStep = .selectContact
    @State private var isSaving = false
    @State private var extractionError: String?
    @State private var showingError = false
    @State private var speechService = SpeechService()

    private let extractionService = ExtractionService()

    enum LogStep {
        case selectContact
        case writeNote
    }

    var canSave: Bool {
        selectedPerson != nil && !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .selectContact:
                    contactSelectionStep
                case .writeNote:
                    noteInputStep
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let person = preselectedPerson {
                selectedPerson = person
                currentStep = .writeNote
            }
        }
    }

    private var navigationTitle: String {
        switch currentStep {
        case .selectContact: return "Select Person"
        case .writeNote: return "Log Interaction"
        }
    }

    private var contactSelectionStep: some View {
        ContactPickerView { person in
            selectedPerson = person
            currentStep = .writeNote
        }
    }

    private var noteInputStep: some View {
        Form {
            if let person = selectedPerson {
                Section {
                    HStack {
                        PersonAvatarView(person: person, size: 44)
                        VStack(alignment: .leading) {
                            Text(person.displayName)
                                .font(.headline)
                            Text("Selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Change") {
                            currentStep = .selectContact
                        }
                        .font(.caption)
                    }
                }
            }

            Section("Interaction Type") {
                Picker("Type", selection: $interactionType) {
                    ForEach(InteractionType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("When") {
                DatePicker("Date", selection: $occurredAt, displayedComponents: [.date, .hourAndMinute])
            }

            Section {
                VStack(spacing: 12) {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 120)

                    // Dictation button
                    Button {
                        toggleDictation()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: speechService.isRecording ? "mic.fill" : "mic")
                                .font(.title2)
                                .symbolEffect(.pulse, isActive: speechService.isRecording)

                            Text(speechService.isRecording ? "Tap to Stop" : "Tap to Dictate")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(speechService.isRecording ? .white : .accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(speechService.isRecording ? Color.red : Color.accentColor.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(speechService.isRecording ? Color.red : Color.accentColor, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    if speechService.isRecording && !speechService.transcribedText.isEmpty {
                        Text(speechService.transcribedText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    if let error = speechService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            } header: {
                Text("What happened?")
            }

            Section {
                Button {
                    saveTouchpoint()
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Saving...")
                                .fontWeight(.semibold)
                                .padding(.leading, 8)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(!canSave || isSaving)
            }
        }
        .alert("Extraction Info", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(extractionError ?? "Unknown error")
        }
    }

    private func toggleDictation() {
        if speechService.isRecording {
            speechService.stopRecording()
            // Append transcribed text to note
            if !speechService.transcribedText.isEmpty {
                if noteText.isEmpty {
                    noteText = speechService.transcribedText
                } else {
                    noteText += " " + speechService.transcribedText
                }
                speechService.transcribedText = ""
            }
        } else {
            Task {
                do {
                    speechService.transcribedText = ""
                    try await speechService.startRecording()
                } catch {
                    print("Failed to start recording: \(error)")
                }
            }
        }
    }

    private func saveTouchpoint() {
        guard let person = selectedPerson else { return }

        isSaving = true

        let touchpoint = Touchpoint(
            rawNote: noteText.trimmingCharacters(in: .whitespacesAndNewlines),
            interactionType: interactionType,
            occurredAt: occurredAt,
            primaryPerson: person
        )

        // Insert and explicitly add to person's touchpoints
        modelContext.insert(touchpoint)
        person.touchpoints.append(touchpoint)

        do {
            try modelContext.save()
            print("Saved touchpoint: \(touchpoint.rawNote) for \(person.displayName)")
            print("Person now has \(person.touchpoints.count) touchpoints")
        } catch {
            print("Failed to save: \(error)")
            isSaving = false
            return
        }

        // Run extraction in background
        Task {
            do {
                try await extractionService.extractAndSave(
                    touchpoint: touchpoint,
                    modelContext: modelContext
                )
                print("Extraction completed successfully")
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Extraction failed: \(error.localizedDescription)")
                await MainActor.run {
                    isSaving = false
                    // Still dismiss but show what happened
                    if let apiError = error as? ClaudeAPIError {
                        extractionError = "Note saved. AI extraction skipped: \(apiError.localizedDescription)"
                    } else {
                        extractionError = "Note saved. AI extraction skipped: \(error.localizedDescription)"
                    }
                    showingError = true
                    // Dismiss after short delay so user sees the saved note
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    LogTouchpointView()
        .modelContainer(for: [Person.self, Touchpoint.self, Fact.self, PersonRelationship.self], inMemory: true)
}
