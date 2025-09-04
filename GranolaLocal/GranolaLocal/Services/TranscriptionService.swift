import Foundation
import WhisperKit
import AVFoundation

class TranscriptionService: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var availableModels: [String] = []
    @Published var selectedModel: String = "openai_whisper-base.en"
    
    private var whisperKit: WhisperKit?
    private var isModelLoaded = false
    
    init() {
        loadAvailableModels()
    }
    
    // MARK: - Model Management
    
    private func loadAvailableModels() {
        // WhisperKit available models for English
        availableModels = [
            "openai_whisper-tiny.en",
            "openai_whisper-base.en", 
            "openai_whisper-small.en",
            "openai_whisper-medium.en",
            "openai_whisper-large-v2",
            "openai_whisper-large-v3"
        ]
    }
    
    func initializeWhisperKit() async throws {
        guard !isModelLoaded else { return }
        
        do {
            whisperKit = try await WhisperKit(modelFolder: selectedModel)
            isModelLoaded = true
            
            DispatchQueue.main.async {
                self.errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load Whisper model: \(error.localizedDescription)"
            }
            throw TranscriptionError.modelLoadFailed(error.localizedDescription)
        }
    }
    
    func changeModel(to modelName: String) async {
        guard modelName != selectedModel else { return }
        
        selectedModel = modelName
        isModelLoaded = false
        whisperKit = nil
        
        do {
            try await initializeWhisperKit()
        } catch {
            print("Failed to switch to model \(modelName): \(error)")
        }
    }
    
    // MARK: - Transcription
    
    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        // Ensure model is loaded
        if !isModelLoaded {
            try await initializeWhisperKit()
        }
        
        guard let whisperKit = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }
        
        DispatchQueue.main.async {
            self.isTranscribing = true
            self.transcriptionProgress = 0.0
            self.errorMessage = nil
        }
        
        do {
            // Load and prepare audio
            let audioData = try loadAudioData(from: audioURL)
            
            // Set up progress callback
            let options = DecodingOptions(
                verbose: true,
                task: .transcribe,
                language: "en",
                temperature: 0.0,
                temperatureIncrementOnFallback: 0.2,
                temperatureFallbackCount: 3,
                skipSpecialTokens: true,
                withoutTimestamps: false
            )
            
            // Perform transcription
            let result = try await whisperKit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: options
            ) { progress in
                DispatchQueue.main.async {
                    self.transcriptionProgress = progress.fractionCompleted
                }
            }
            
            DispatchQueue.main.async {
                self.isTranscribing = false
                self.transcriptionProgress = 1.0
            }
            
            return TranscriptionResult(
                text: result.text,
                segments: result.segments.map { segment in
                    TranscriptionSegment(
                        text: segment.text,
                        startTime: segment.start,
                        endTime: segment.end,
                        confidence: 0.0 // WhisperKit doesn't provide confidence scores
                    )
                },
                language: result.language ?? "en"
            )
            
        } catch {
            DispatchQueue.main.async {
                self.isTranscribing = false
                self.errorMessage = "Transcription failed: \(error.localizedDescription)"
            }
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }
    
    private func loadAudioData(from url: URL) throws -> [Float] {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw TranscriptionError.audioProcessingFailed("Could not create audio buffer")
        }
        
        try audioFile.read(into: buffer)
        
        guard let floatChannelData = buffer.floatChannelData else {
            throw TranscriptionError.audioProcessingFailed("Could not get float channel data")
        }
        
        let frameLength = Int(buffer.frameLength)
        let audioData = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameLength))
        
        return audioData
    }
    
    // MARK: - Utility Methods
    
    func estimateTranscriptionTime(for audioURL: URL) -> TimeInterval {
        do {
            let audioFile = try AVAudioFile(forReading: audioURL)
            let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            
            // Rough estimate: transcription takes about 1/4 to 1/2 of audio duration
            // depending on model size and hardware
            let multiplier: Double
            switch selectedModel {
            case let model where model.contains("tiny"):
                multiplier = 0.1
            case let model where model.contains("base"):
                multiplier = 0.2
            case let model where model.contains("small"):
                multiplier = 0.3
            case let model where model.contains("medium"):
                multiplier = 0.4
            case let model where model.contains("large"):
                multiplier = 0.5
            default:
                multiplier = 0.3
            }
            
            return duration * multiplier
        } catch {
            return 60.0 // Default estimate
        }
    }
    
    func getModelSize() -> String {
        switch selectedModel {
        case let model where model.contains("tiny"):
            return "~39 MB"
        case let model where model.contains("base"):
            return "~142 MB"
        case let model where model.contains("small"):
            return "~488 MB"
        case let model where model.contains("medium"):
            return "~1.5 GB"
        case let model where model.contains("large"):
            return "~3.1 GB"
        default:
            return "Unknown"
        }
    }
    
    func getModelDescription() -> String {
        switch selectedModel {
        case let model where model.contains("tiny"):
            return "Fastest transcription, lower accuracy"
        case let model where model.contains("base"):
            return "Good balance of speed and accuracy"
        case let model where model.contains("small"):
            return "Better accuracy, slower transcription"
        case let model where model.contains("medium"):
            return "High accuracy, requires more time"
        case let model where model.contains("large"):
            return "Highest accuracy, longest processing time"
        default:
            return "Multilingual model with high accuracy"
        }
    }
}

// MARK: - Supporting Types

struct TranscriptionResult {
    let text: String
    let segments: [TranscriptionSegment]
    let language: String
    
    var formattedText: String {
        // Format the text with proper punctuation and paragraphs
        var formatted = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add basic formatting improvements
        formatted = formatted.replacingOccurrences(of: " .", with: ".")
        formatted = formatted.replacingOccurrences(of: " ,", with: ",")
        formatted = formatted.replacingOccurrences(of: " ?", with: "?")
        formatted = formatted.replacingOccurrences(of: " !", with: "!")
        
        return formatted
    }
    
    var wordCount: Int {
        text.split(separator: " ").count
    }
    
    var duration: TimeInterval {
        guard let lastSegment = segments.last else { return 0 }
        return lastSegment.endTime
    }
}

struct TranscriptionSegment {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Double
    
    var formattedTimeRange: String {
        let startMinutes = Int(startTime) / 60
        let startSeconds = Int(startTime) % 60
        let endMinutes = Int(endTime) / 60
        let endSeconds = Int(endTime) % 60
        
        return String(format: "%02d:%02d - %02d:%02d", startMinutes, startSeconds, endMinutes, endSeconds)
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(String)
    case transcriptionFailed(String)
    case audioProcessingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model not loaded"
        case .modelLoadFailed(let message):
            return "Model load failed: \(message)"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .audioProcessingFailed(let message):
            return "Audio processing failed: \(message)"
        }
    }
}
