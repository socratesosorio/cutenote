import SwiftUI

@main
struct GranolaLocalApp: App {
    @StateObject private var notesManager = NotesManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var transcriptionService = TranscriptionService()
    @StateObject private var aiProcessor = AIProcessor()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notesManager)
                .environmentObject(audioManager)
                .environmentObject(transcriptionService)
                .environmentObject(aiProcessor)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        
        Settings {
            SettingsView()
                .environmentObject(notesManager)
                .environmentObject(audioManager)
                .environmentObject(transcriptionService)
                .environmentObject(aiProcessor)
        }
    }
}
