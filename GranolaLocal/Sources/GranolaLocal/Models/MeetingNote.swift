import Foundation

enum NoteTemplate: String, CaseIterable, Identifiable, Codable {
    case auto = "Auto"
    case oneOnOne = "1:1 Meeting"
    case standup = "Stand-up"
    case salesCall = "Sales Call"
    case interview = "Interview"
    case projectKickoff = "Project Kick-off"
    case retrospective = "Retrospective"
    case customerDiscovery = "Customer Discovery"
    
    var id: String { rawValue }
    
    var sections: [String] {
        switch self {
        case .auto:
            return ["Summary", "Key Points", "Decisions", "Action Items"]
        case .oneOnOne:
            return ["Goals", "Discussion", "Outcomes", "Next Steps"]
        case .standup:
            return ["What was done", "What's planned", "Blockers", "Updates"]
        case .salesCall:
            return ["About the client", "Needs", "Objections", "Next Steps"]
        case .interview:
            return ["Candidate Background", "Technical Discussion", "Questions Asked", "Assessment", "Next Steps"]
        case .projectKickoff:
            return ["Project Overview", "Goals & Objectives", "Team & Roles", "Timeline", "Next Steps"]
        case .retrospective:
            return ["What went well", "What could be improved", "Action items", "Team feedback"]
        case .customerDiscovery:
            return ["Customer Goals", "Pain Points", "Current Solutions", "Key Insights", "Follow-up"]
        }
    }
    
    var icon: String {
        switch self {
        case .auto: return "sparkles"
        case .oneOnOne: return "person.2"
        case .standup: return "clock"
        case .salesCall: return "briefcase"
        case .interview: return "questionmark.circle"
        case .projectKickoff: return "rocket"
        case .retrospective: return "arrow.clockwise"
        case .customerDiscovery: return "magnifyingglass"
        }
    }
}

enum RecordingState: String, CaseIterable, Codable {
    case idle = "idle"
    case recording = "recording"
    case processing = "processing"
    case transcribing = "transcribing"
    case enhancing = "enhancing"
    case completed = "completed"
    case error = "error"
}

class MeetingNote: ObservableObject, Identifiable, Codable, Hashable {
    let id = UUID()
    @Published var title: String
    @Published var date: Date
    @Published var userNotes: String
    @Published var transcript: String
    @Published var enhancedNotes: String
    @Published var template: NoteTemplate
    @Published var recordingState: RecordingState
    @Published var folder: String
    @Published var audioFilePath: String?
    @Published var recordingDuration: TimeInterval
    @Published var isStarred: Bool
    
    // Chat history for Q&A
    @Published var chatHistory: [ChatMessage]
    
    init(title: String = "", 
         template: NoteTemplate = .auto,
         folder: String = "All Notes") {
        self.title = title.isEmpty ? "Meeting \(Self.dateFormatter.string(from: Date()))" : title
        self.date = Date()
        self.userNotes = ""
        self.transcript = ""
        self.enhancedNotes = ""
        self.template = template
        self.recordingState = .idle
        self.folder = folder
        self.audioFilePath = nil
        self.recordingDuration = 0
        self.isStarred = false
        self.chatHistory = []
    }
    
    // MARK: - Hashable Implementation
    static func == (lhs: MeetingNote, rhs: MeetingNote) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case id, title, date, userNotes, transcript, enhancedNotes
        case template, recordingState, folder, audioFilePath
        case recordingDuration, isStarred, chatHistory
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        userNotes = try container.decode(String.self, forKey: .userNotes)
        transcript = try container.decode(String.self, forKey: .transcript)
        enhancedNotes = try container.decode(String.self, forKey: .enhancedNotes)
        template = try container.decode(NoteTemplate.self, forKey: .template)
        recordingState = try container.decode(RecordingState.self, forKey: .recordingState)
        folder = try container.decode(String.self, forKey: .folder)
        audioFilePath = try container.decodeIfPresent(String.self, forKey: .audioFilePath)
        recordingDuration = try container.decode(TimeInterval.self, forKey: .recordingDuration)
        isStarred = try container.decode(Bool.self, forKey: .isStarred)
        chatHistory = try container.decode([ChatMessage].self, forKey: .chatHistory)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)
        try container.encode(userNotes, forKey: .userNotes)
        try container.encode(transcript, forKey: .transcript)
        try container.encode(enhancedNotes, forKey: .enhancedNotes)
        try container.encode(template, forKey: .template)
        try container.encode(recordingState, forKey: .recordingState)
        try container.encode(folder, forKey: .folder)
        try container.encode(audioFilePath, forKey: .audioFilePath)
        try container.encode(recordingDuration, forKey: .recordingDuration)
        try container.encode(isStarred, forKey: .isStarred)
        try container.encode(chatHistory, forKey: .chatHistory)
    }
    
    // MARK: - Helper Methods
    
    var isEmpty: Bool {
        userNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        transcript.isEmpty &&
        enhancedNotes.isEmpty
    }
    
    var hasTranscript: Bool {
        !transcript.isEmpty
    }
    
    var hasEnhancedNotes: Bool {
        !enhancedNotes.isEmpty
    }
    
    var canEnhance: Bool {
        hasTranscript && recordingState == .completed
    }
    
    var isProcessing: Bool {
        recordingState == .processing || 
        recordingState == .transcribing || 
        recordingState == .enhancing
    }
    
    func formattedDuration() -> String {
        let hours = Int(recordingDuration) / 3600
        let minutes = Int(recordingDuration) % 3600 / 60
        let seconds = Int(recordingDuration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct ChatMessage: Identifiable, Codable, Hashable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    
    init(content: String, isUser: Bool) {
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case id, content, isUser, timestamp
    }
}
