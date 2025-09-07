import XCTest
@testable import GranolaLocal
import AVFoundation

final class WorkflowTests: XCTestCase {
    var notesManager: NotesManager!
    var audioManager: AudioManager!
    var transcriptionService: TranscriptionService!
    var aiProcessor: AIProcessor!
    
    override func setUpWithError() throws {
        notesManager = NotesManager()
        audioManager = AudioManager()
        transcriptionService = TranscriptionService()
        aiProcessor = AIProcessor()
    }
    
    override func tearDownWithError() throws {
        notesManager = nil
        audioManager = nil
        transcriptionService = nil
        aiProcessor = nil
    }
    
    func testNoteCreation() throws {
        let note = notesManager.createNewNote(title: "Test Meeting", template: .standup)
        
        XCTAssertEqual(note.title, "Test Meeting")
        XCTAssertEqual(note.template, .standup)
        XCTAssertEqual(note.recordingState, .idle)
        XCTAssertTrue(note.userNotes.isEmpty)
        XCTAssertTrue(note.transcript.isEmpty)
        XCTAssertTrue(note.enhancedNotes.isEmpty)
    }
    
    func testTemplateGeneration() throws {
        let templates = NoteTemplate.allCases
        XCTAssertTrue(templates.count >= 8)
        
        for template in templates {
            XCTAssertFalse(template.sections.isEmpty)
            XCTAssertFalse(template.icon.isEmpty)
        }
    }
    
    func testAudioManagerInitialization() throws {
        XCTAssertFalse(audioManager.isRecording)
        XCTAssertEqual(audioManager.recordingDuration, 0)
        XCTAssertEqual(audioManager.audioLevel, 0.0)
    }
    
    func testTranscriptionServiceInitialization() throws {
        XCTAssertFalse(transcriptionService.isTranscribing)
        XCTAssertEqual(transcriptionService.transcriptionProgress, 0.0)
        XCTAssertFalse(transcriptionService.availableModels.isEmpty)
        XCTAssertEqual(transcriptionService.selectedModel, "openai_whisper-base.en")
    }
    
    func testAIProcessorInitialization() throws {
        XCTAssertFalse(aiProcessor.isProcessing)
        XCTAssertEqual(aiProcessor.apiKeyStatus, .notSet)
    }
    
    func testNotePersistence() throws {
        let note = notesManager.createNewNote(title: "Persistence Test")
        note.userNotes = "Test content"
        
        // Save the note
        notesManager.saveNote(note)
        
        // Reload notes
        notesManager.loadNotes()
        
        // Find the saved note
        let savedNote = notesManager.notes.first { $0.title == "Persistence Test" }
        XCTAssertNotNil(savedNote)
        XCTAssertEqual(savedNote?.userNotes, "Test content")
    }
    
    func testFolderManagement() throws {
        let initialFolderCount = notesManager.folders.count
        
        notesManager.createFolder("Test Folder")
        XCTAssertEqual(notesManager.folders.count, initialFolderCount + 1)
        XCTAssertTrue(notesManager.folders.contains("Test Folder"))
        
        notesManager.deleteFolder("Test Folder")
        XCTAssertEqual(notesManager.folders.count, initialFolderCount)
        XCTAssertFalse(notesManager.folders.contains("Test Folder"))
    }
    
    func testSearchFunctionality() throws {
        // Clear existing notes
        notesManager.notes.removeAll()
        
        let note1 = notesManager.createNewNote(title: "Meeting about project alpha")
        note1.userNotes = "Discussed timeline and budget"
        
        let note2 = notesManager.createNewNote(title: "Weekly standup")
        note2.userNotes = "Team updates and blockers"
        
        // Test search by title
        notesManager.searchText = "alpha"
        XCTAssertEqual(notesManager.filteredNotes.count, 1)
        XCTAssertEqual(notesManager.filteredNotes.first?.title, "Meeting about project alpha")
        
        // Test search by content
        notesManager.searchText = "timeline"
        XCTAssertEqual(notesManager.filteredNotes.count, 1)
        
        // Clear search
        notesManager.searchText = ""
        XCTAssertEqual(notesManager.filteredNotes.count, notesManager.notes.count)
    }
    
    func testExportFunctionality() throws {
        let note = notesManager.createNewNote(title: "Export Test")
        note.userNotes = "# Test Heading\n\n- Bullet point 1\n- Bullet point 2"
        note.enhancedNotes = "## Enhanced Notes\n\nThis is enhanced content."
        
        // Test Markdown export
        let markdownURL = try notesManager.exportNote(note, format: .markdown)
        XCTAssertTrue(FileManager.default.fileExists(atPath: markdownURL.path))
        
        let markdownContent = try String(contentsOf: markdownURL)
        XCTAssertTrue(markdownContent.contains("# Export Test"))
        XCTAssertTrue(markdownContent.contains("## Enhanced Notes"))
        
        // Clean up
        try? FileManager.default.removeItem(at: markdownURL)
    }
    
    func testRecordingStateTransitions() throws {
        let note = notesManager.createNewNote(title: "Recording Test")
        
        // Initial state
        XCTAssertEqual(note.recordingState, .idle)
        
        // Simulate recording
        note.recordingState = .recording
        XCTAssertEqual(note.recordingState, .recording)
        XCTAssertFalse(note.isProcessing) // Recording is not considered processing
        
        // Simulate transcription
        note.recordingState = .transcribing
        XCTAssertEqual(note.recordingState, .transcribing)
        XCTAssertTrue(note.isProcessing)
        
        // Simulate completion
        note.recordingState = .completed
        XCTAssertEqual(note.recordingState, .completed)
        XCTAssertFalse(note.isProcessing)
    }
    
    func testChatMessageHandling() throws {
        let note = notesManager.createNewNote(title: "Chat Test")
        
        let userMessage = ChatMessage(content: "What were the action items?", isUser: true)
        let aiMessage = ChatMessage(content: "The action items were: 1. Follow up with client, 2. Prepare presentation", isUser: false)
        
        note.chatHistory.append(userMessage)
        note.chatHistory.append(aiMessage)
        
        XCTAssertEqual(note.chatHistory.count, 2)
        XCTAssertTrue(note.chatHistory[0].isUser)
        XCTAssertFalse(note.chatHistory[1].isUser)
    }
    
    // Performance test for large transcript handling
    func testLargeTranscriptPerformance() throws {
        let note = notesManager.createNewNote(title: "Large Transcript Test")
        
        // Create a large transcript (simulating 1-hour meeting)
        let largeTranscript = String(repeating: "This is a sample sentence in a long meeting transcript. ", count: 10000)
        note.transcript = largeTranscript
        
        measure {
            // Test search performance
            notesManager.searchText = "sample"
            _ = notesManager.filteredNotes
            notesManager.searchText = ""
        }
    }
}

// MARK: - Test Utilities

extension WorkflowTests {
    func createSampleAudioFile() throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent("test_audio.wav")
        
        // Create a simple sine wave for testing
        let sampleRate: Double = 16000
        let duration: Double = 1.0
        let frequency: Double = 440.0 // A4 note
        
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let audioFile = try AVAudioFile(forWriting: audioURL, settings: format.settings)
        
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        let channelData = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let sample = Float(sin(2.0 * Double.pi * frequency * Double(i) / sampleRate))
            channelData[i] = sample * 0.1 // Lower volume
        }
        
        try audioFile.write(from: buffer)
        return audioURL
    }
}
