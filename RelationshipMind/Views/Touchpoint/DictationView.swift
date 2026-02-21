import SwiftUI

struct DictationTextEditor: View {
    @Binding var text: String
    @State private var speechService = SpeechService()
    @State private var showingError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $text)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGray6))
                .cornerRadius(8)

            HStack {
                // Dictation button
                Button {
                    toggleRecording()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: speechService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title2)
                            .foregroundColor(speechService.isRecording ? .red : .accentColor)
                            .symbolEffect(.pulse, isActive: speechService.isRecording)

                        Text(speechService.isRecording ? "Stop" : "Dictate")
                            .font(.subheadline)
                            .foregroundColor(speechService.isRecording ? .red : .accentColor)
                    }
                }

                Spacer()

                if !text.isEmpty {
                    Button("Clear") {
                        text = ""
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            if speechService.isRecording {
                HStack(spacing: 8) {
                    RecordingIndicator()
                    Text("Listening...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onChange(of: speechService.transcribedText) { _, newValue in
            if !newValue.isEmpty {
                // Append transcribed text
                if text.isEmpty {
                    text = newValue
                } else if !text.hasSuffix(newValue) {
                    // Only update if it's new content
                    text = newValue
                }
            }
        }
        .alert("Dictation Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = speechService.errorMessage {
                Text(error)
            }
        }
        .onChange(of: speechService.errorMessage) { _, newValue in
            if newValue != nil {
                showingError = true
            }
        }
    }

    private func toggleRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            // Reset transcription for new recording session
            speechService.transcribedText = ""

            Task {
                do {
                    try await speechService.startRecording()
                } catch {
                    speechService.errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

struct RecordingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Capsule()
                    .fill(Color.red)
                    .frame(width: 3, height: isAnimating ? 12 : 6)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    @Previewable @State var text = ""
    return DictationTextEditor(text: $text)
        .padding()
}
