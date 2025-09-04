# GranolaLocal Development Guide

This guide covers the technical implementation details and development workflow for GranolaLocal.

## Architecture Overview

GranolaLocal follows the MVVM (Model-View-ViewModel) pattern using SwiftUI and Combine:

### Core Components

```
┌─────────────────┐
│   SwiftUI Views │ ← User Interface Layer
├─────────────────┤
│ Observable      │ ← State Management  
│ Objects         │   (AudioManager, AIProcessor, etc.)
├─────────────────┤
│ Services        │ ← Business Logic
│                 │   (Whisper, OpenAI, File I/O)
├─────────────────┤
│ Models          │ ← Data Models
│                 │   (MeetingNote, Templates)
└─────────────────┘
```

### Data Flow

1. **Audio Capture**: `AudioManager` → AVAudioEngine → Local file
2. **Transcription**: Local file → `TranscriptionService` (Whisper) → Text
3. **Enhancement**: Text → `AIProcessor` (GPT) → Enhanced notes
4. **Persistence**: `NotesManager` → Local JSON files

## Key Design Decisions

### Privacy-First Architecture

- **Local Transcription**: Whisper runs entirely on-device
- **Minimal Cloud Usage**: Only text sent to OpenAI, never audio
- **User Control**: Explicit consent for each AI feature
- **Local Storage**: All data in user's Documents folder

### Performance Optimizations

- **Background Processing**: Heavy operations on background queues
- **Model Loading**: Lazy loading of Whisper models
- **Memory Management**: Automatic cleanup of audio buffers
- **Efficient UI**: SwiftUI state management with minimal re-renders

### Extensibility

- **Template System**: Easy to add new meeting templates
- **Export Formats**: Pluggable export system
- **AI Providers**: Abstracted AI interface for future providers

## Component Details

### AudioManager

**Purpose**: Handles audio recording from microphone and system audio

**Key Features**:
- Multi-input audio capture (mic + BlackHole)
- Real-time audio level monitoring
- Configurable audio formats
- Permission management

**Implementation Notes**:
```swift
// Core recording setup
let audioEngine = AVAudioEngine()
let inputNode = audioEngine.inputNode
let recordingFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)

// Install tap for recording
inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
    try audioFile.write(from: buffer)
}
```

### TranscriptionService

**Purpose**: Local speech-to-text using OpenAI's Whisper

**Key Features**:
- Multiple model sizes (tiny to large)
- English-optimized models
- Progress reporting
- Background processing

**Model Selection**:
- `tiny.en`: Fast, lower accuracy (~39MB)
- `base.en`: Balanced speed/accuracy (~142MB)  
- `small.en`: Better accuracy (~488MB)
- `medium.en`: High accuracy (~1.5GB)
- `large-v3`: Highest accuracy (~3.1GB)

### AIProcessor

**Purpose**: OpenAI GPT integration for note enhancement and Q&A

**Key Features**:
- Configurable API key management
- Template-based prompt generation
- Conversation context for Q&A
- Error handling and retry logic

**Prompt Engineering**:
```swift
// Enhancement prompt structure
let prompt = """
MEETING TRANSCRIPT: \(transcript)
USER NOTES: \(userNotes)
TEMPLATE: \(template.sections)

Create enhanced notes that:
- Incorporate user's original structure
- Add details from transcript
- Follow template format
- Include decisions and action items
"""
```

### NotesManager

**Purpose**: Data persistence and organization

**Key Features**:
- JSON-based storage
- Folder organization
- Search and filtering
- Export functionality
- Backup and recovery

**File Structure**:
```
~/Documents/GranolaLocal/
├── Notes/
│   ├── [uuid].json        # Individual notes
│   └── folders.json       # Folder configuration
├── Recordings/            # Audio files (optional)
├── Exports/              # Exported notes
└── Logs/                 # Debug logs
```

## Development Workflow

### Getting Started

1. **Clone and Setup**:
   ```bash
   git clone <repo>
   cd granola-local
   ./setup.sh
   ```

2. **Open in Xcode**:
   ```bash
   open GranolaLocal/GranolaLocal.xcodeproj
   ```

3. **Install Dependencies**:
   Dependencies are managed via Swift Package Manager and automatically resolved.

### Building

**Debug Build**:
```bash
xcodebuild -project GranolaLocal.xcodeproj -scheme GranolaLocal -configuration Debug build
```

**Release Build**:
```bash
xcodebuild -project GranolaLocal.xcodeproj -scheme GranolaLocal -configuration Release build
```

### Testing

**Unit Tests**: Run via Xcode Test Navigator or:
```bash
xcodebuild test -project GranolaLocal.xcodeproj -scheme GranolaLocal
```

**Manual Testing Checklist**:
- [ ] Audio recording and playback
- [ ] Transcription accuracy with test audio
- [ ] Note enhancement with sample text
- [ ] Q&A responses
- [ ] Export functionality
- [ ] Settings persistence

### Debugging

**Audio Issues**:
```swift
// Enable audio debugging
audioEngine.isVoiceProcessingEnabled = false
print("Input node format: \(audioEngine.inputNode.outputFormat(forBus: 0))")
```

**Transcription Issues**:
```swift
// Log Whisper model info
print("Model loaded: \(whisperKit.modelPath)")
print("Estimated time: \(transcriptionService.estimateTranscriptionTime(for: audioURL))")
```

**AI Issues**:
```swift
// Debug API calls
print("Prompt sent to GPT: \(prompt)")
print("Response: \(response)")
```

## Code Style Guidelines

### Swift Conventions

- Use SwiftUI property wrappers consistently
- Prefer `@StateObject` for managers, `@ObservedObject` for passed objects
- Use `private` for implementation details
- Document public APIs with Swift DocC comments

### Error Handling

```swift
enum AudioError: LocalizedError {
    case recordingFailed(String)
    case deviceNotFound
    
    var errorDescription: String? {
        switch self {
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .deviceNotFound:
            return "Audio device not found"
        }
    }
}
```

### Async/Await Pattern

```swift
func transcribeAudio() async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
        transcriptionService.transcribe(audioURL) { result in
            switch result {
            case .success(let transcript):
                continuation.resume(returning: transcript)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}
```

## Performance Considerations

### Memory Management

- **Audio Buffers**: Released immediately after processing
- **Whisper Models**: Loaded on-demand, cached during session
- **Large Transcripts**: Chunked for GPT processing if needed

### CPU Usage

- **Background Queues**: All heavy processing on background threads
- **Model Selection**: Smaller models for older hardware
- **Progress Reporting**: Regular updates without blocking UI

### Storage

- **Audio Cleanup**: Optional deletion after transcription
- **Compression**: JSON files for efficient storage
- **Caching**: Reasonable limits on cached data

## Security Considerations

### Local Data Protection

- **Sandboxing**: App sandbox enabled with minimal permissions
- **File Access**: Only user-selected directories and Documents
- **Encryption**: System-level encryption via FileVault

### API Security

- **Key Storage**: API keys in Keychain or UserDefaults (user choice)
- **Network**: HTTPS only for OpenAI API calls
- **Validation**: Input sanitization for AI prompts

### Privacy Compliance

- **Consent**: Clear disclosure of AI usage
- **Control**: User can disable AI features entirely
- **Transparency**: Open source for audit

## Extending the App

### Adding New Templates

1. **Define Template**:
   ```swift
   case newTemplate = "New Template"
   
   var sections: [String] {
       case .newTemplate:
           return ["Section 1", "Section 2", "Section 3"]
   }
   ```

2. **Update Prompts** in `AIProcessor.swift`
3. **Test** with sample data

### Adding Export Formats

1. **Extend Enum**:
   ```swift
   enum ExportFormat {
       case newFormat = "New Format"
       
       var fileExtension: String {
           case .newFormat: return "xyz"
       }
   }
   ```

2. **Implement Export** in `NotesManager.swift`
3. **Update UI** in export sheet

### Adding AI Providers

1. **Create Protocol**:
   ```swift
   protocol AIProviderProtocol {
       func enhanceNotes(transcript: String, notes: String) async throws -> String
       func answerQuestion(question: String, context: String) async throws -> String
   }
   ```

2. **Implement Provider**
3. **Update Settings** for provider selection

## Troubleshooting

### Common Issues

**Build Failures**:
- Check Xcode version (15.0+ required)
- Clean build folder (⌘+Shift+K)
- Reset Package Dependencies

**Runtime Errors**:
- Check entitlements for required permissions
- Verify API key configuration
- Check audio device availability

**Performance Issues**:
- Profile with Instruments
- Check for memory leaks
- Monitor CPU usage during transcription

### Debugging Tools

**Xcode Instruments**:
- Time Profiler for CPU usage
- Allocations for memory leaks
- Network for API calls

**Console Logs**:
```bash
log stream --predicate 'subsystem CONTAINS "com.granolalocal.app"'
```

**Audio MIDI Setup**:
- Verify BlackHole installation
- Check aggregate device configuration

## Contributing

### Pull Request Process

1. **Fork** the repository
2. **Create Feature Branch**: `git checkout -b feature/amazing-feature`
3. **Implement** with tests
4. **Document** changes
5. **Submit PR** with description

### Code Review Checklist

- [ ] Follows Swift style guidelines
- [ ] Includes appropriate error handling
- [ ] Updates documentation
- [ ] Maintains privacy principles
- [ ] Tests on multiple macOS versions

---

For questions or clarifications, open an issue or start a discussion on GitHub.
