import SwiftUI

struct NoteDetailView: View {
    @ObservedObject var note: MeetingNote
    @EnvironmentObject var notesManager: NotesManager
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var transcriptionService: TranscriptionService
    @EnvironmentObject var aiProcessor: AIProcessor
    
    @State private var showingChat = false
    @State private var showingExportSheet = false
    @State private var isRecording = false
    @State private var recordingURL: URL?
    @State private var showingTemplateSelector = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()
            
            Divider()
            
            // Main content area
            HSplitView {
                // Note editor
                NoteEditorView()
                    .frame(minWidth: 400)
                
                // Chat panel (conditional)
                if showingChat {
                    ChatView(note: note)
                        .frame(width: 350)
                }
            }
        }
        .navigationTitle(note.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if note.hasTranscript {
                    Button("Ask AI") {
                        showingChat.toggle()
                    }
                    .help("Chat with AI about this meeting")
                }
                
                Button("Export") {
                    showingExportSheet = true
                }
                .help("Export this note")
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportView(note: note)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Sync recording state
            isRecording = audioManager.isRecording
        }
        .onChange(of: audioManager.isRecording) { newValue in
            isRecording = newValue
        }
    }
    
    @ViewBuilder
    private func HeaderView() -> some View {
        HStack {
            // Title editor
            TextField("Meeting Title", text: $note.title)
                .font(.title2)
                .fontWeight(.semibold)
                .textFieldStyle(.plain)
                .onSubmit {
                    notesManager.saveNote(note)
                }
            
            Spacer()
            
            // Template selector
            Menu {
                ForEach(NoteTemplate.allCases) { template in
                    Button {
                        note.template = template
                        notesManager.saveNote(note)
                    } label: {
                        HStack {
                            if note.template == template {
                                Image(systemName: "checkmark")
                            }
                            Label(template.rawValue, systemImage: template.icon)
                        }
                    }
                }
            } label: {
                Label(note.template.rawValue, systemImage: note.template.icon)
                    .foregroundColor(.blue)
            }
            .menuStyle(.borderlessButton)
            
            // Recording controls
            RecordingControls()
            
            // Status indicator
            if note.isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private func RecordingControls() -> some View {
        if isRecording {
            HStack {
                Button("Stop Recording") {
                    stopRecording()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                // Recording duration
                Text(formatDuration(audioManager.recordingDuration))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                
                // Audio level indicator
                AudioLevelMeter(level: audioManager.audioLevel)
            }
        } else {
            Button("Start Recording") {
                startRecording()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(note.isProcessing)
        }
    }
    
    @ViewBuilder
    private func NoteEditorView() -> some View {
        VStack(spacing: 0) {
            // Action buttons bar
            if !isRecording && note.hasTranscript && !note.hasEnhancedNotes {
                HStack {
                    Button("Enhance Notes") {
                        enhanceNotes()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(aiProcessor.isProcessing || aiProcessor.apiKeyStatus != .valid)
                    
                    Spacer()
                    
                    if aiProcessor.apiKeyStatus != .valid {
                        Text("Configure OpenAI API key in Settings")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }
            
            // Text editor
            VStack(alignment: .leading, spacing: 12) {
                if note.hasEnhancedNotes {
                    // Enhanced notes view
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Enhanced Notes")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button("Re-enhance") {
                                enhanceNotes()
                            }
                            .font(.caption)
                            .disabled(aiProcessor.isProcessing)
                        }
                        
                        ScrollView {
                            Text(LocalizedStringKey(note.enhancedNotes))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    if !note.userNotes.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Original Notes")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $note.userNotes)
                                .font(.body)
                                .frame(minHeight: 100)
                                .onChange(of: note.userNotes) { _ in
                                    notesManager.saveNote(note)
                                }
                        }
                    }
                } else {
                    // Regular note editor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meeting Notes")
                            .font(.headline)
                        
                        if isRecording {
                            Text("Meeting in progress... you can jot down notes here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        
                        TextEditor(text: $note.userNotes)
                            .font(.body)
                            .onChange(of: note.userNotes) { _ in
                                notesManager.saveNote(note)
                            }
                    }
                }
                
                // Transcript section (if available)
                if note.hasTranscript && !note.hasEnhancedNotes {
                    Divider()
                    
                    DisclosureGroup("Transcript") {
                        ScrollView {
                            Text(note.transcript)
                                .textSelection(.enabled)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Recording Actions
    
    private func startRecording() {
        Task {
            do {
                note.recordingState = .recording
                recordingURL = try await audioManager.startRecording(for: note)
                notesManager.saveNote(note)
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
                note.recordingState = .error
            }
        }
    }
    
    private func stopRecording() {
        audioManager.stopRecording()
        note.recordingDuration = audioManager.recordingDuration
        note.recordingState = .processing
        notesManager.saveNote(note)
        
        // Start transcription
        if let url = recordingURL {
            note.audioFilePath = url.path
            transcribeAudio(url: url)
        }
    }
    
    private func transcribeAudio(url: URL) {
        Task {
            do {
                note.recordingState = .transcribing
                notesManager.saveNote(note)
                
                let result = try await transcriptionService.transcribe(audioURL: url)
                
                DispatchQueue.main.async {
                    self.note.transcript = result.formattedText
                    self.note.recordingState = .completed
                    self.notesManager.saveNote(self.note)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Transcription failed: \(error.localizedDescription)"
                    self.showingError = true
                    self.note.recordingState = .error
                    self.notesManager.saveNote(self.note)
                }
            }
        }
    }
    
    private func enhanceNotes() {
        Task {
            do {
                note.recordingState = .enhancing
                notesManager.saveNote(note)
                
                let enhanced = try await aiProcessor.enhanceNotes(
                    userNotes: note.userNotes,
                    transcript: note.transcript,
                    template: note.template
                )
                
                DispatchQueue.main.async {
                    self.note.enhancedNotes = enhanced
                    self.note.recordingState = .completed
                    self.notesManager.saveNote(self.note)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Enhancement failed: \(error.localizedDescription)"
                    self.showingError = true
                    self.note.recordingState = .error
                    self.notesManager.saveNote(self.note)
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct AudioLevelMeter: View {
    let level: Float
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Rectangle()
                    .fill(level > Float(index) * 0.2 ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 3, height: 8)
            }
        }
    }
}

struct ExportView: View {
    let note: MeetingNote
    @EnvironmentObject var notesManager: NotesManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFormat: ExportFormat = .markdown
    @State private var isExporting = false
    @State private var exportError: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Export Note")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Format:")
                    .font(.subheadline)
                
                Picker("Format", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            if let error = exportError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Export") {
                    exportNote()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isExporting)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func exportNote() {
        isExporting = true
        exportError = nil
        
        do {
            let exportURL = try notesManager.exportNote(note, format: selectedFormat)
            NSWorkspace.shared.selectFile(exportURL.path, inFileViewerRootedAtPath: exportURL.deletingLastPathComponent().path)
            dismiss()
        } catch {
            exportError = error.localizedDescription
        }
        
        isExporting = false
    }
}

#Preview {
    NoteDetailView(note: MeetingNote(title: "Sample Meeting"))
        .environmentObject(NotesManager())
        .environmentObject(AudioManager())
        .environmentObject(TranscriptionService())
        .environmentObject(AIProcessor())
}
