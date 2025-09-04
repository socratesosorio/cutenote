import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var transcriptionService: TranscriptionService
    @EnvironmentObject var aiProcessor: AIProcessor
    @EnvironmentObject var notesManager: NotesManager
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: SettingsTab = .general
    @State private var apiKey = ""
    @State private var showingAPIKeyAlert = false
    @State private var keepAudioFiles = false
    @State private var autoEnhanceNotes = false
    @State private var showingResetAlert = false
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case audio = "Audio"
        case ai = "AI & Privacy"
        case advanced = "Advanced"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .audio: return "mic"
            case .ai: return "brain.head.profile"
            case .advanced: return "wrench.and.screwdriver"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
        } detail: {
            // Detail view
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .audio:
                    AudioSettingsView()
                case .ai:
                    AISettingsView()
                case .advanced:
                    AdvancedSettingsView()
                }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        apiKey = aiProcessor.getAPIKey() ?? ""
        keepAudioFiles = UserDefaults.standard.bool(forKey: "keepAudioFiles")
        autoEnhanceNotes = UserDefaults.standard.bool(forKey: "autoEnhanceNotes")
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var notesManager: NotesManager
    @State private var autoEnhanceNotes = false
    @State private var keepAudioFiles = false
    @State private var defaultTemplate: NoteTemplate = .auto
    
    var body: some View {
        Form {
            Section("Default Settings") {
                Picker("Default Template", selection: $defaultTemplate) {
                    ForEach(NoteTemplate.allCases) { template in
                        Label(template.rawValue, systemImage: template.icon)
                            .tag(template)
                    }
                }
                
                Toggle("Auto-enhance notes after transcription", isOn: $autoEnhanceNotes)
                    .help("Automatically run AI enhancement when transcription completes")
                
                Toggle("Keep audio recordings", isOn: $keepAudioFiles)
                    .help("Save audio files after transcription (uses more storage)")
            }
            
            Section("Storage") {
                let stats = notesManager.statistics
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Statistics")
                        .font(.headline)
                    
                    Grid(alignment: .leading) {
                        GridRow {
                            Text("Total Notes:")
                            Text("\(stats.totalNotes)")
                                .foregroundColor(.secondary)
                        }
                        
                        GridRow {
                            Text("Total Folders:")
                            Text("\(stats.totalFolders)")
                                .foregroundColor(.secondary)
                        }
                        
                        GridRow {
                            Text("Recording Time:")
                            Text(stats.formattedRecordingTime)
                                .foregroundColor(.secondary)
                        }
                        
                        GridRow {
                            Text("With Transcripts:")
                            Text("\(stats.notesWithTranscripts)")
                                .foregroundColor(.secondary)
                        }
                        
                        GridRow {
                            Text("AI Enhanced:")
                            Text("\(stats.notesWithEnhancements)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Button("Open Data Folder") {
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let granolaPath = documentsPath.appendingPathComponent("GranolaLocal")
                    NSWorkspace.shared.open(granolaPath)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .onAppear {
            autoEnhanceNotes = UserDefaults.standard.bool(forKey: "autoEnhanceNotes")
            keepAudioFiles = UserDefaults.standard.bool(forKey: "keepAudioFiles")
            if let templateName = UserDefaults.standard.string(forKey: "defaultTemplate"),
               let template = NoteTemplate.allCases.first(where: { $0.rawValue == templateName }) {
                defaultTemplate = template
            }
        }
        .onChange(of: autoEnhanceNotes) { newValue in
            UserDefaults.standard.set(newValue, forKey: "autoEnhanceNotes")
        }
        .onChange(of: keepAudioFiles) { newValue in
            UserDefaults.standard.set(newValue, forKey: "keepAudioFiles")
        }
        .onChange(of: defaultTemplate) { newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "defaultTemplate")
        }
    }
}

struct AudioSettingsView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var transcriptionService: TranscriptionService
    @State private var showingBlackHoleInfo = false
    
    var body: some View {
        Form {
            Section("Audio Setup") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("To capture meeting audio from Zoom, Teams, etc., you need BlackHole:")
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Download BlackHole") {
                            if let url = URL(string: "https://github.com/ExistentialAudio/BlackHole") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Setup Instructions") {
                            showingBlackHoleInfo = true
                        }
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Input Devices")
                        .font(.headline)
                    
                    if audioManager.availableInputDevices.isEmpty {
                        Text("No audio devices found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(audioManager.availableInputDevices) { device in
                            HStack {
                                Image(systemName: device.name.lowercased().contains("blackhole") ? "speaker.wave.2" : "mic")
                                Text(device.name)
                                Spacer()
                                if device.id == audioManager.selectedInputDevice?.id {
                                    Text("Selected")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                }
                            }
                            .onTapGesture {
                                audioManager.selectInputDevice(device)
                            }
                        }
                    }
                }
            }
            
            Section("Transcription") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Whisper Model")
                        .font(.headline)
                    
                    Picker("Model", selection: $transcriptionService.selectedModel) {
                        ForEach(transcriptionService.availableModels, id: \.self) { model in
                            VStack(alignment: .leading) {
                                Text(model.replacingOccurrences(of: "openai_whisper-", with: "").uppercased())
                                Text(transcriptionService.getModelDescription())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text("Size: \(transcriptionService.getModelSize())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(transcriptionService.getModelDescription())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Audio")
        .sheet(isPresented: $showingBlackHoleInfo) {
            BlackHoleSetupView()
        }
    }
}

struct AISettingsView: View {
    @EnvironmentObject var aiProcessor: AIProcessor
    @State private var apiKey = ""
    @State private var showingAPIKeyInfo = false
    @State private var isTestingKey = false
    
    var body: some View {
        Form {
            Section("OpenAI Configuration") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("API Key")
                        .font(.headline)
                    
                    HStack {
                        SecureField("sk-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Test") {
                            testAPIKey()
                        }
                        .disabled(apiKey.isEmpty || isTestingKey)
                        
                        if isTestingKey {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    HStack {
                        StatusIndicator(status: aiProcessor.apiKeyStatus)
                        
                        Button("Get API Key") {
                            if let url = URL(string: "https://platform.openai.com/api-keys") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .font(.caption)
                    }
                    
                    if let error = aiProcessor.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            
            Section("Privacy & Data") {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Audio stays on your Mac", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Label("Transcription happens locally", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Label("Only text sent to OpenAI for enhancement", systemImage: "info.circle")
                        .foregroundColor(.blue)
                    
                    Text("When you use AI features, meeting transcripts are sent to OpenAI's servers for processing. No audio is ever uploaded.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            }
            
            Section("Usage Guidelines") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Inform meeting participants about recording")
                    Text("• Review AI-generated content for accuracy")
                    Text("• Your OpenAI API usage will be charged to your account")
                    Text("• Consider your organization's data policies")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("AI & Privacy")
        .onAppear {
            apiKey = aiProcessor.getAPIKey() ?? ""
        }
        .onChange(of: apiKey) { newValue in
            aiProcessor.setAPIKey(newValue)
        }
    }
    
    private func testAPIKey() {
        isTestingKey = true
        Task {
            await aiProcessor.testAPIKey()
            DispatchQueue.main.async {
                self.isTestingKey = false
            }
        }
    }
}

struct AdvancedSettingsView: View {
    @EnvironmentObject var notesManager: NotesManager
    @State private var showingResetAlert = false
    
    var body: some View {
        Form {
            Section("Data Management") {
                Button("Export All Notes") {
                    exportAllNotes()
                }
                
                Button("Reset All Settings") {
                    showingResetAlert = true
                }
                .foregroundColor(.red)
            }
            
            Section("Debug") {
                Button("Show Log Files") {
                    showLogFiles()
                }
                
                Button("Test Notification") {
                    sendTestNotification()
                }
            }
            
            Section("About") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GranolaLocal")
                        .font(.headline)
                    
                    Text("Version 1.0.0")
                        .foregroundColor(.secondary)
                    
                    Text("AI-powered meeting notes that respect your privacy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Advanced")
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will reset all settings to defaults. Your notes will not be affected.")
        }
    }
    
    private func exportAllNotes() {
        // Implementation for bulk export
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.folder]
        panel.prompt = "Choose Export Location"
        
        if panel.runModal() == .OK, let url = panel.url {
            // Export all notes to the selected folder
            Task {
                for note in notesManager.notes {
                    do {
                        _ = try notesManager.exportNote(note, format: .markdown)
                    } catch {
                        print("Failed to export \(note.title): \(error)")
                    }
                }
            }
        }
    }
    
    private func showLogFiles() {
        let logsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GranolaLocal/Logs")
        NSWorkspace.shared.open(logsPath)
    }
    
    private func sendTestNotification() {
        let notification = NSUserNotification()
        notification.title = "GranolaLocal"
        notification.informativeText = "Test notification successful!"
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    private func resetAllSettings() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "autoEnhanceNotes")
        defaults.removeObject(forKey: "keepAudioFiles")
        defaults.removeObject(forKey: "defaultTemplate")
        defaults.removeObject(forKey: "hasSeenOnboarding")
    }
}

struct StatusIndicator: View {
    let status: AIProcessor.APIKeyStatus
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .notSet: return "exclamationmark.circle"
        case .valid: return "checkmark.circle.fill"
        case .invalid: return "xmark.circle.fill"
        case .testing: return "clock"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .notSet: return .orange
        case .valid: return .green
        case .invalid: return .red
        case .testing: return .blue
        }
    }
    
    private var statusText: String {
        switch status {
        case .notSet: return "Not configured"
        case .valid: return "Valid"
        case .invalid: return "Invalid"
        case .testing: return "Testing..."
        }
    }
}

struct BlackHoleSetupView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("BlackHole Setup Instructions")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("BlackHole is a virtual audio driver that allows GranolaLocal to capture system audio from meeting apps like Zoom, Teams, etc.")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Setup Steps:")
                    .font(.headline)
                
                Group {
                    Text("1. Download and install BlackHole from the link provided")
                    Text("2. Open System Preferences → Sound → Output")
                    Text("3. Select 'BlackHole 2ch' as your output device")
                    Text("4. In GranolaLocal, BlackHole should appear as an input option")
                    Text("5. Start your meeting app and begin recording in GranolaLocal")
                }
                .font(.body)
                .padding(.leading)
            }
            
            Text("Note: You may need to use headphones or external speakers to hear meeting audio while recording.")
                .font(.caption)
                .foregroundColor(.orange)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            
            HStack {
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Download BlackHole") {
                    if let url = URL(string: "https://github.com/ExistentialAudio/BlackHole") {
                        NSWorkspace.shared.open(url)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 500)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AudioManager())
        .environmentObject(TranscriptionService())
        .environmentObject(AIProcessor())
        .environmentObject(NotesManager())
}
