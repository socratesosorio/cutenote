# GranolaLocal - AI-Powered Meeting Notes for macOS

GranolaLocal is a privacy-first, AI-powered meeting notes application for macOS that captures, transcribes, and enhances your meeting notes entirely on your local machine. Inspired by Granola, it provides intelligent note-taking capabilities while keeping your data completely private.

## Features

### 🎙️ Audio Recording
- **System Audio Capture**: Records both your voice and meeting participants using BlackHole audio driver
- **High-Quality Recording**: 16kHz audio optimized for speech recognition
- **Live Audio Monitoring**: Visual feedback during recording

### 🤖 AI-Powered Intelligence
- **Local Transcription**: Uses OpenAI's Whisper model running entirely on your Mac
- **Smart Note Enhancement**: GPT-4 integration for intelligent note improvement
- **Interactive Q&A**: Chat with AI about your meeting content
- **Multiple Templates**: Pre-built templates for different meeting types

### 🏠 Privacy-First Design
- **Local Processing**: Audio never leaves your Mac
- **Encrypted Storage**: All data stored locally with user control
- **Optional AI**: Choose when to use cloud-based AI features
- **No Accounts**: No sign-ups or external dependencies

### 📝 Rich Note-Taking
- **Real-time Editing**: Take notes during meetings
- **Markdown Support**: Rich formatting for beautiful notes
- **Template System**: Structured formats for different meeting types
- **Export Options**: Markdown, plain text, and JSON export

## Requirements

- **macOS 13.0+** (Apple Silicon recommended for best performance)
- **BlackHole Audio Driver** (for system audio capture)
- **OpenAI API Key** (for AI features - optional)
- **Microphone Access** (required for recording)

## Installation

### 1. Clone and Build

```bash
git clone https://github.com/your-username/granola-local.git
cd granola-local/GranolaLocal
open GranolaLocal.xcodeproj
```

Build and run in Xcode, or use the command line:

```bash
xcodebuild -project GranolaLocal.xcodeproj -scheme GranolaLocal -configuration Release build
```

### 2. Install BlackHole (Required for System Audio)

BlackHole is a free, open-source virtual audio driver that enables capturing system audio:

1. Download BlackHole from: https://github.com/ExistentialAudio/BlackHole
2. Run the installer
3. Restart your Mac
4. The app will guide you through audio setup on first launch

### 3. Configure Audio Setup

After installing BlackHole:

1. **System Preferences → Sound → Output**: Select "BlackHole 2ch"
2. **For hearing audio**: Use headphones or create a Multi-Output Device in Audio MIDI Setup
3. **In GranolaLocal**: BlackHole will appear as an input option

### 4. OpenAI API Setup (Optional)

For AI features (note enhancement and Q&A):

1. Get an API key from: https://platform.openai.com/api-keys
2. Open GranolaLocal → Settings → AI & Privacy
3. Enter your API key and test the connection

## Usage

### Starting a Meeting

1. **Create New Note**: Click the "+" button and select a template
2. **Start Recording**: Click the red "Start Recording" button
3. **Take Notes**: Type key points during the meeting
4. **Stop Recording**: Click "Stop Recording" when the meeting ends

### After the Meeting

1. **Automatic Transcription**: Audio is transcribed locally using Whisper
2. **Enhance Notes**: Click "Enhance Notes" to have AI improve your notes
3. **Ask Questions**: Use the "Ask AI" feature to query the meeting content
4. **Export/Share**: Export as Markdown, plain text, or JSON

### Templates

Choose from pre-built templates or let AI auto-organize:

- **Auto**: AI decides the best structure
- **1:1 Meeting**: Goals, Discussion, Outcomes, Next Steps
- **Stand-up**: What was done, What's planned, Blockers, Updates
- **Sales Call**: About the client, Needs, Objections, Next Steps
- **Interview**: Background, Technical Discussion, Assessment
- **Project Kick-off**: Overview, Goals, Team & Roles, Timeline
- **Retrospective**: What went well, Improvements, Action items

## Privacy & Security

### What Stays Local
- ✅ Audio recordings (deleted after transcription by default)
- ✅ Speech-to-text transcription (processed by local Whisper model)
- ✅ All note data and metadata
- ✅ Search and organization

### What Uses Cloud (Optional)
- 🔒 Text-only content sent to OpenAI for enhancement (when you click "Enhance")
- 🔒 Q&A interactions (transcript text sent for question answering)

### Data Storage
All data is stored locally in `~/Documents/GranolaLocal/`:
- `Notes/` - Individual note files (JSON format)
- `Recordings/` - Audio files (if keeping enabled)
- `Exports/` - Exported notes

## Performance Tips

### For Best Transcription Performance
- **Apple Silicon Macs**: Excellent performance with large Whisper models
- **Intel Macs**: Use smaller models (base/small) for reasonable speed
- **Memory**: 8GB+ RAM recommended for large models
- **Storage**: ~3GB for largest Whisper model

### Audio Quality Tips
- Use a good microphone for your voice
- Ensure stable internet for meeting participants' audio
- Test audio levels before important meetings
- Consider using headphones to avoid feedback

## Troubleshooting

### Audio Issues
- **Can't hear meeting audio**: Set up Multi-Output Device in Audio MIDI Setup
- **No system audio captured**: Ensure BlackHole is set as output device
- **Microphone not working**: Check System Preferences → Security & Privacy → Microphone

### Transcription Issues
- **Slow transcription**: Switch to a smaller Whisper model in Settings
- **Poor accuracy**: Use the larger English-specific models
- **App crashes**: Reduce model size or close other memory-intensive apps

### AI Features
- **Enhancement not working**: Check API key in Settings → AI & Privacy
- **Slow responses**: Check internet connection
- **Costs**: Monitor usage on OpenAI dashboard

## Development

### Project Structure
```
GranolaLocal/
├── Models/
│   └── MeetingNote.swift          # Core data models
├── Services/
│   ├── AudioManager.swift         # Audio recording
│   ├── TranscriptionService.swift # Whisper integration
│   ├── AIProcessor.swift          # OpenAI integration
│   └── NotesManager.swift         # Data persistence
├── Views/
│   ├── ContentView.swift          # Main app structure
│   ├── NoteDetailView.swift       # Note editor
│   ├── ChatView.swift             # Q&A interface
│   └── SettingsView.swift         # Configuration
└── GranolaLocalApp.swift          # App entry point
```

### Dependencies
- **WhisperKit**: Local speech-to-text transcription
- **OpenAI**: GPT integration for enhancement and Q&A
- **AVFoundation**: Audio recording and processing
- **SwiftUI**: Native macOS interface

### Building
1. Open `GranolaLocal.xcodeproj` in Xcode
2. Ensure you have the latest Xcode (15.0+)
3. Build for macOS deployment target 13.0+

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Areas for Contribution
- **Additional Templates**: Meeting-specific note structures
- **Export Formats**: PDF, DOCX, or other formats
- **Languages**: Multi-language transcription support
- **Integrations**: Calendar, Slack, Notion connections
- **Performance**: Optimization for older hardware

## Roadmap

### v1.1 (Next Release)
- [ ] Calendar integration for automatic meeting titles
- [ ] Improved speaker diarization
- [ ] Custom template creation
- [ ] Folder-level AI queries

### v1.2 (Future)
- [ ] iOS companion app
- [ ] Team collaboration features
- [ ] Advanced audio processing
- [ ] Plugin system for integrations

## License

GranolaLocal is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- **OpenAI** for Whisper and GPT models
- **ExistentialAudio** for the BlackHole audio driver
- **Granola** for inspiration and UX patterns
- **Apple** for excellent development tools and frameworks

## Support

- **Issues**: Report bugs on GitHub Issues
- **Discussions**: Join GitHub Discussions for questions
- **Email**: support@granola-local.com

---

**Note**: This is an independent project inspired by Granola but not affiliated with the original Granola team.
