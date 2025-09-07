import SwiftUI

struct ContentView: View {
    @EnvironmentObject var notesManager: NotesManager
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var transcriptionService: TranscriptionService
    @EnvironmentObject var aiProcessor: AIProcessor
    
    @State private var showingSettings = false
    @State private var showingOnboarding = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } content: {
            NotesListView()
                .navigationSplitViewColumnWidth(min: 300, ideal: 400)
        } detail: {
            if let selectedNote = notesManager.selectedNote {
                NoteDetailView(note: selectedNote)
            } else {
                EmptyStateView()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
        }
        .onAppear {
            checkOnboardingStatus()
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                }
            }
        }
    }
    
    private func checkOnboardingStatus() {
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        if !hasSeenOnboarding {
            showingOnboarding = true
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var notesManager: NotesManager
    @State private var showingNewFolderDialog = false
    @State private var newFolderName = ""
    
    var body: some View {
        List(selection: $notesManager.selectedFolder) {
            Section("Folders") {
                ForEach(notesManager.folders, id: \.self) { folder in
                    HStack {
                        Image(systemName: folder == "All Notes" ? "tray.full" : "folder")
                            .foregroundColor(.blue)
                        Text(folder)
                        Spacer()
                        Text("\(notesCount(for: folder))")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .tag(folder)
                    .contextMenu {
                        if folder != "All Notes" {
                            Button("Rename") {
                                // TODO: Implement rename
                            }
                            Button("Delete", role: .destructive) {
                                DispatchQueue.main.async {
                                    notesManager.deleteFolder(folder)
                                }
                            }
                        }
                    }
                }
            }
            
            Section("Quick Access") {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Starred")
                    Spacer()
                    Text("\(notesManager.starredNotes.count)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.green)
                    Text("Recent")
                    Spacer()
                    Text("\(min(notesManager.recentNotes.count, 10))")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("GranolaLocal")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingNewFolderDialog = true }) {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingNewFolderDialog) {
            NewFolderDialog(
                folderName: $newFolderName,
                onSave: {
                    notesManager.createFolder(newFolderName)
                    newFolderName = ""
                    showingNewFolderDialog = false
                },
                onCancel: {
                    newFolderName = ""
                    showingNewFolderDialog = false
                }
            )
        }
    }
    
    private func notesCount(for folder: String) -> Int {
        if folder == "All Notes" {
            return notesManager.notes.count
        }
        return notesManager.notes.filter { $0.folder == folder }.count
    }
}

struct NotesListView: View {
    @EnvironmentObject var notesManager: NotesManager
    @State private var showingNewNoteOptions = false
    
    var body: some View {
        List(selection: $notesManager.selectedNote) {
            ForEach(notesManager.filteredNotes) { note in
                NoteRowView(note: note)
                    .tag(note)
                    .contextMenu {
                        Button("Duplicate") {
                            DispatchQueue.main.async {
                                _ = notesManager.duplicateNote(note)
                            }
                        }
                        Button("Star") {
                            DispatchQueue.main.async {
                                note.isStarred.toggle()
                                notesManager.saveNote(note)
                            }
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            DispatchQueue.main.async {
                                notesManager.deleteNote(note)
                            }
                        }
                    }
            }
        }
        .listStyle(PlainListStyle())
        .searchable(text: $notesManager.searchText, prompt: "Search notes...")
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(NoteTemplate.allCases) { template in
                        Button {
                            let note = notesManager.createNewNote(template: template)
                            notesManager.selectedNote = note
                        } label: {
                            Label(template.rawValue, systemImage: template.icon)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct NoteRowView: View {
    @ObservedObject var note: MeetingNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                if note.isStarred {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
                
                RecordingStateIndicator(state: note.recordingState)
            }
            
            HStack {
                Text(note.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(note.template.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if note.recordingDuration > 0 {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(note.formattedDuration())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if !note.enhancedNotes.isEmpty {
                Text(note.enhancedNotes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else if !note.userNotes.isEmpty {
                Text(note.userNotes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

struct RecordingStateIndicator: View {
    let state: RecordingState
    
    var body: some View {
        Group {
            switch state {
            case .idle:
                EmptyView()
            case .recording:
                HStack(spacing: 2) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .scaleEffect(animationScale)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: animationScale)
                    Text("REC")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            case .processing, .transcribing:
                HStack(spacing: 2) {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("Processing")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            case .enhancing:
                HStack(spacing: 2) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundColor(.purple)
                    Text("Enhancing")
                        .font(.caption2)
                        .foregroundColor(.purple)
                }
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }
    
    @State private var animationScale: CGFloat = 1.0
}

struct EmptyStateView: View {
    @EnvironmentObject var notesManager: NotesManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Note Selected")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Select a note from the sidebar or create a new one to get started")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Create New Note") {
                let note = notesManager.createNewNote()
                notesManager.selectedNote = note
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NewFolderDialog: View {
    @Binding var folderName: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Folder")
                .font(.headline)
            
            TextField("Folder Name", text: $folderName)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Button("Create", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

#Preview {
    ContentView()
        .environmentObject(NotesManager())
        .environmentObject(AudioManager())
        .environmentObject(TranscriptionService())
        .environmentObject(AIProcessor())
}
