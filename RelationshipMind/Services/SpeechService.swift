import Foundation
import Speech
import AVFoundation

@Observable
final class SpeechService {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    var isRecording = false
    var transcribedText = ""
    var errorMessage: String?

    var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            errorMessage = "Speech recognition not authorized"
            return false
        }

        // Request microphone permission
        let micStatus = await AVAudioApplication.requestRecordPermission()

        guard micStatus else {
            errorMessage = "Microphone access not authorized"
            return false
        }

        return true
    }

    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    // MARK: - Recording

    func startRecording() async throws {
        // Check authorization
        if authorizationStatus != .authorized {
            let authorized = await requestAuthorization()
            if !authorized {
                throw SpeechError.notAuthorized
            }
        }

        // Cancel any ongoing task
        stopRecording()

        // Create new audio engine
        audioEngine = AVAudioEngine()

        guard let audioEngine = audioEngine else {
            throw SpeechError.requestCreationFailed
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        if #available(iOS 16, *) {
            recognitionRequest.addsPunctuation = true
        }

        // Get input node and its native format
        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        // Check if the format is valid
        guard nativeFormat.sampleRate > 0 && nativeFormat.channelCount > 0 else {
            throw SpeechError.requestCreationFailed
        }

        // Install tap using the input node's native format
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nativeFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true
        errorMessage = nil

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }

            if let error = error {
                DispatchQueue.main.async {
                    // Ignore cancellation errors
                    let nsError = error as NSError
                    if nsError.code != 216 && nsError.code != 1 {
                        self.errorMessage = error.localizedDescription
                    }
                    self.stopRecording()
                }
            }

            if result?.isFinal == true {
                DispatchQueue.main.async {
                    self.stopRecording()
                }
            }
        }
    }

    func stopRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if let engine = audioEngine, engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil

        isRecording = false

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func reset() {
        stopRecording()
        transcribedText = ""
        errorMessage = nil
    }
}

// MARK: - Errors

enum SpeechError: LocalizedError {
    case notAuthorized
    case requestCreationFailed
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition or microphone access not authorized. Please enable in Settings."
        case .requestCreationFailed:
            return "Failed to start recording. Please try again."
        case .recognitionFailed:
            return "Speech recognition failed."
        }
    }
}
