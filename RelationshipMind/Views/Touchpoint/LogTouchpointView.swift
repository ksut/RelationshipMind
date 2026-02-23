import SwiftUI
import SwiftData

struct LogTouchpointView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var preselectedPerson: Person?
    var isNoteOnly: Bool = false

    @State private var selectedPerson: Person?
    @State private var interactionType: InteractionType = .inPerson
    @State private var noteText = ""
    @State private var occurredAt = Date()
    @State private var currentStep: LogStep = .selectContact
    @State private var isSaving = false
    @State private var extractionError: String?
    @State private var showingError = false
    @State private var speechService = SpeechService()

    // Review flow state
    @State private var showingExtractionReview = false
    @State private var extractionResult: ExtractionResult?
    @State private var savedTouchpoint: Touchpoint?

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
        .sheet(isPresented: $showingExtractionReview) {
            if let touchpoint = savedTouchpoint, let result = extractionResult {
                ExtractionReviewView(
                    touchpoint: touchpoint,
                    extraction: Binding(
                        get: { self.extractionResult ?? result },
                        set: { self.extractionResult = $0 }
                    ),
                    onConfirm: { confirmExtraction() },
                    onCancel: { cancelExtraction() }
                )
                .interactiveDismissDisabled()
            }
        }
    }

    private var navigationTitle: String {
        switch currentStep {
        case .selectContact: return "Select Person"
        case .writeNote: return isNoteOnly ? "Add Note" : "Log Interaction"
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

            if !isNoteOnly {
                Section("Interaction Type") {
                    Picker("Type", selection: $interactionType) {
                        ForEach(InteractionType.allCases.filter { $0.countsAsInteraction }, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("When") {
                    DatePicker("Date", selection: $occurredAt, displayedComponents: [.date, .hourAndMinute])
                }
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
                Text(isNoteOnly ? "What do you want to remember?" : "What happened?")
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
                            Text("Extracting...")
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
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(extractionError ?? "Unknown error")
        }
    }

    private func toggleDictation() {
        if speechService.isRecording {
            HapticService.lightImpact()
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
            HapticService.lightImpact()
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
            interactionType: isNoteOnly ? .note : interactionType,
            occurredAt: occurredAt,
            primaryPerson: person
        )

        // Auto-track person when logging an interaction
        if !person.isTracked {
            person.isTracked = true
        }

        // Insert and explicitly add to person's touchpoints
        modelContext.insert(touchpoint)
        person.touchpoints.append(touchpoint)

        do {
            try modelContext.save()
            HapticService.success()
            print("Saved touchpoint: \(touchpoint.rawNote) for \(person.displayName)")
        } catch {
            print("Failed to save: \(error)")
            isSaving = false
            return
        }

        savedTouchpoint = touchpoint

        // Run extraction (Phase A only — no database writes)
        Task {
            do {
                let result = try await extractionService.extract(
                    touchpoint: touchpoint,
                    modelContext: modelContext
                )
                await MainActor.run {
                    isSaving = false
                    extractionResult = result
                    showingExtractionReview = true
                }
            } catch {
                print("Extraction failed: \(error.localizedDescription)")
                await MainActor.run {
                    isSaving = false
                    if let apiError = error as? ClaudeAPIError {
                        extractionError = "Note saved. AI extraction skipped: \(apiError.localizedDescription)"
                    } else {
                        extractionError = "Note saved. AI extraction skipped: \(error.localizedDescription)"
                    }
                    showingError = true
                }
            }
        }
    }

    private func confirmExtraction() {
        guard let touchpoint = savedTouchpoint, let result = extractionResult else { return }

        do {
            try extractionService.saveExtractionResult(
                result,
                touchpoint: touchpoint,
                modelContext: modelContext
            )
            HapticService.success()
            print("Extraction confirmed and saved")
        } catch {
            print("Failed to save extraction: \(error)")
        }

        showingExtractionReview = false
        dismiss()
    }

    private func cancelExtraction() {
        showingExtractionReview = false
        dismiss()
    }
}

#Preview {
    LogTouchpointView()
        .modelContainer(for: [Person.self, Touchpoint.self, Fact.self, PersonRelationship.self], inMemory: true)
}
