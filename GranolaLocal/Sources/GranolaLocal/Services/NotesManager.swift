import Foundation
import Combine

class NotesManager: ObservableObject {
    @Published var notes: [MeetingNote] = []
    @Published var folders: [String] = ["All Notes"]
    @Published var selectedFolder: String = "All Notes"
    @Published var selectedNote: MeetingNote?
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let granolaDirectory: URL
    private let notesDirectory: URL
    
    init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        granolaDirectory = documentsDirectory.appendingPathComponent("GranolaLocal")
        notesDirectory = granolaDirectory.appendingPathComponent("Notes")
        
        createDirectoriesIfNeeded()
        loadNotes()
        loadFolders()
    }
    
    // MARK: - Directory Management
    
    private func createDirectoriesIfNeeded() {
        let directories = [
            granolaDirectory,
            notesDirectory,
            granolaDirectory.appendingPathComponent("Recordings"),
            granolaDirectory.appendingPathComponent("Exports")
        ]
        
        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }
    
    // MARK: - Notes Management
    
    func createNewNote(title: String = "", template: NoteTemplate = .auto, folder: String? = nil) -> MeetingNote {
        let note = MeetingNote(
            title: title,
            template: template,
            folder: folder ?? selectedFolder
        )
        
        notes.append(note)
        selectedNote = note
        
        // Add folder if it doesn't exist
        if let folder = folder, !folders.contains(folder) {
            folders.append(folder)
        }
        
        saveNote(note)
        return note
    }
    
    func deleteNote(_ note: MeetingNote) {
        // Delete associated files
        deleteNoteFiles(note)
        
        // Remove from array
        notes.removeAll { $0.id == note.id }
        
        // Update selection
        if selectedNote?.id == note.id {
            selectedNote = notes.first
        }
    }
    
    func duplicateNote(_ note: MeetingNote) -> MeetingNote {
        let duplicatedNote = MeetingNote(
            title: "\(note.title) - Copy",
            template: note.template,
            folder: note.folder
        )
        
        duplicatedNote.userNotes = note.userNotes
        duplicatedNote.transcript = note.transcript
        duplicatedNote.enhancedNotes = note.enhancedNotes
        // Don't copy audio file or chat history
        
        notes.append(duplicatedNote)
        saveNote(duplicatedNote)
        
        return duplicatedNote
    }
    
    func saveNote(_ note: MeetingNote) {
        do {
            let noteData = try JSONEncoder().encode(note)
            let filename = "\(note.id.uuidString).json"
            let fileURL = notesDirectory.appendingPathComponent(filename)
            
            try noteData.write(to: fileURL)
            
        } catch {
            errorMessage = "Failed to save note: \(error.localizedDescription)"
        }
    }
    
    func loadNotes() {
        isLoading = true
        notes.removeAll()
        
        do {
            let noteFiles = try fileManager.contentsOfDirectory(at: notesDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in noteFiles where fileURL.pathExtension == "json" {
                do {
                    let noteData = try Data(contentsOf: fileURL)
                    let note = try JSONDecoder().decode(MeetingNote.self, from: noteData)
                    notes.append(note)
                } catch {
                    print("Failed to load note from \(fileURL): \(error)")
                }
            }
            
            // Sort notes by date (newest first)
            notes.sort { $0.date > $1.date }
            
        } catch {
            errorMessage = "Failed to load notes: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func deleteNoteFiles(_ note: MeetingNote) {
        // Delete JSON file
        let filename = "\(note.id.uuidString).json"
        let jsonURL = notesDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: jsonURL)
        
        // Delete audio file if exists
        if let audioPath = note.audioFilePath {
            let audioURL = URL(fileURLWithPath: audioPath)
            try? fileManager.removeItem(at: audioURL)
        }
    }
    
    // MARK: - Folder Management
    
    func createFolder(_ name: String) {
        guard !folders.contains(name) && !name.isEmpty else { return }
        folders.append(name)
        saveFolders()
    }
    
    func deleteFolder(_ name: String) {
        guard name != "All Notes" else { return }
        
        // Move notes in this folder to "All Notes"
        for note in notes where note.folder == name {
            note.folder = "All Notes"
            saveNote(note)
        }
        
        folders.removeAll { $0 == name }
        
        if selectedFolder == name {
            selectedFolder = "All Notes"
        }
        
        saveFolders()
    }
    
    func renameFolder(_ oldName: String, to newName: String) {
        guard oldName != "All Notes" && !folders.contains(newName) && !newName.isEmpty else { return }
        
        // Update notes in this folder
        for note in notes where note.folder == oldName {
            note.folder = newName
            saveNote(note)
        }
        
        // Update folders array
        if let index = folders.firstIndex(of: oldName) {
            folders[index] = newName
        }
        
        if selectedFolder == oldName {
            selectedFolder = newName
        }
        
        saveFolders()
    }
    
    func moveNote(_ note: MeetingNote, to folder: String) {
        note.folder = folder
        saveNote(note)
        
        if !folders.contains(folder) {
            folders.append(folder)
            saveFolders()
        }
    }
    
    private func loadFolders() {
        let foldersURL = granolaDirectory.appendingPathComponent("folders.json")
        
        do {
            let data = try Data(contentsOf: foldersURL)
            let loadedFolders = try JSONDecoder().decode([String].self, from: data)
            folders = loadedFolders
        } catch {
            // If loading fails, use default folders and extract from existing notes
            folders = ["All Notes"]
            let uniqueFolders = Set(notes.map { $0.folder })
            for folder in uniqueFolders {
                if !folders.contains(folder) {
                    folders.append(folder)
                }
            }
        }
    }
    
    private func saveFolders() {
        let foldersURL = granolaDirectory.appendingPathComponent("folders.json")
        
        do {
            let data = try JSONEncoder().encode(folders)
            try data.write(to: foldersURL)
        } catch {
            errorMessage = "Failed to save folders: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Search and Filtering
    
    var filteredNotes: [MeetingNote] {
        var filtered = notes
        
        // Filter by folder
        if selectedFolder != "All Notes" {
            filtered = filtered.filter { $0.folder == selectedFolder }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.userNotes.localizedCaseInsensitiveContains(searchText) ||
                note.enhancedNotes.localizedCaseInsensitiveContains(searchText) ||
                note.transcript.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var starredNotes: [MeetingNote] {
        notes.filter { $0.isStarred }
    }
    
    var recentNotes: [MeetingNote] {
        Array(notes.prefix(10))
    }
    
    // MARK: - Export Functions
    
    func exportNote(_ note: MeetingNote, format: ExportFormat) throws -> URL {
        let exportsDirectory = granolaDirectory.appendingPathComponent("Exports")
        let filename = "\(note.title.sanitizedForFilename())_\(formatDate(note.date))"
        
        switch format {
        case .markdown:
            return try exportAsMarkdown(note, to: exportsDirectory, filename: filename)
        case .plainText:
            return try exportAsPlainText(note, to: exportsDirectory, filename: filename)
        case .json:
            return try exportAsJSON(note, to: exportsDirectory, filename: filename)
        }
    }
    
    private func exportAsMarkdown(_ note: MeetingNote, to directory: URL, filename: String) throws -> URL {
        let fileURL = directory.appendingPathComponent("\(filename).md")
        
        var content = "# \(note.title)\n\n"
        content += "**Date:** \(MeetingNote.dateFormatter.string(from: note.date))\n"
        content += "**Template:** \(note.template.rawValue)\n"
        content += "**Folder:** \(note.folder)\n\n"
        
        if !note.enhancedNotes.isEmpty {
            content += "## Enhanced Notes\n\n\(note.enhancedNotes)\n\n"
        }
        
        if !note.userNotes.isEmpty {
            content += "## Original Notes\n\n\(note.userNotes)\n\n"
        }
        
        if !note.transcript.isEmpty {
            content += "## Transcript\n\n\(note.transcript)\n\n"
        }
        
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private func exportAsPlainText(_ note: MeetingNote, to directory: URL, filename: String) throws -> URL {
        let fileURL = directory.appendingPathComponent("\(filename).txt")
        
        var content = "\(note.title)\n"
        content += String(repeating: "=", count: note.title.count) + "\n\n"
        content += "Date: \(MeetingNote.dateFormatter.string(from: note.date))\n"
        content += "Template: \(note.template.rawValue)\n"
        content += "Folder: \(note.folder)\n\n"
        
        if !note.enhancedNotes.isEmpty {
            content += "ENHANCED NOTES\n--------------\n\(note.enhancedNotes)\n\n"
        }
        
        if !note.userNotes.isEmpty {
            content += "ORIGINAL NOTES\n--------------\n\(note.userNotes)\n\n"
        }
        
        if !note.transcript.isEmpty {
            content += "TRANSCRIPT\n----------\n\(note.transcript)\n\n"
        }
        
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private func exportAsJSON(_ note: MeetingNote, to directory: URL, filename: String) throws -> URL {
        let fileURL = directory.appendingPathComponent("\(filename).json")
        let noteData = try JSONEncoder().encode(note)
        try noteData.write(to: fileURL)
        return fileURL
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // MARK: - Statistics
    
    var statistics: NotesStatistics {
        NotesStatistics(
            totalNotes: notes.count,
            totalFolders: folders.count - 1, // Exclude "All Notes"
            averageNotesPerWeek: calculateAverageNotesPerWeek(),
            totalRecordingTime: notes.reduce(0) { $0 + $1.recordingDuration },
            notesWithTranscripts: notes.filter { $0.hasTranscript }.count,
            notesWithEnhancements: notes.filter { $0.hasEnhancedNotes }.count
        )
    }
    
    private func calculateAverageNotesPerWeek() -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        guard let earliestDate = notes.map({ $0.date }).min() else { return 0 }
        
        let weeks = calendar.dateComponents([.weekOfYear], from: earliestDate, to: now).weekOfYear ?? 1
        return Double(notes.count) / Double(max(weeks, 1))
    }
}

// MARK: - Supporting Types

enum ExportFormat: String, CaseIterable {
    case markdown = "Markdown"
    case plainText = "Plain Text"
    case json = "JSON"
    
    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .plainText: return "txt"
        case .json: return "json"
        }
    }
}

struct NotesStatistics {
    let totalNotes: Int
    let totalFolders: Int
    let averageNotesPerWeek: Double
    let totalRecordingTime: TimeInterval
    let notesWithTranscripts: Int
    let notesWithEnhancements: Int
    
    var formattedRecordingTime: String {
        let hours = Int(totalRecordingTime) / 3600
        let minutes = Int(totalRecordingTime) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }
}
