import SwiftUI

struct MainView: View {
    @EnvironmentObject var notesManager: NotesManager
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var transcriptionService: TranscriptionService
    @EnvironmentObject var aiProcessor: AIProcessor
    
    var body: some View {
        ContentView()
    }
}

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    
    private let steps = [
        OnboardingStep(
            title: "Welcome to GranolaLocal",
            description: "Your AI-powered meeting notes app that keeps everything private on your Mac",
            icon: "sparkles",
            color: .blue
        ),
        OnboardingStep(
            title: "Audio Setup Required",
            description: "To capture both your voice and meeting audio, install BlackHole (free audio driver). This allows recording system audio from Zoom, Teams, etc.",
            icon: "mic.fill",
            color: .green,
            action: {
                if let url = URL(string: "https://github.com/ExistentialAudio/BlackHole") {
                    NSWorkspace.shared.open(url)
                }
            },
            actionText: "Download BlackHole"
        ),
        OnboardingStep(
            title: "AI Features",
            description: "GranolaLocal uses OpenAI's GPT for smart note enhancement and Q&A. You'll need to provide your own API key to enable these features.",
            icon: "brain.head.profile",
            color: .purple
        ),
        OnboardingStep(
            title: "Privacy First",
            description: "Audio recording and transcription happen entirely on your Mac. Only text is sent to OpenAI for enhancement when you choose to use AI features.",
            icon: "lock.shield.fill",
            color: .orange
        )
    ]
    
    var body: some View {
        VStack(spacing: 30) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: currentStep)
                }
            }
            .padding(.top)
            
            Spacer()
            
            // Current step content
            let step = steps[currentStep]
            
            VStack(spacing: 20) {
                Image(systemName: step.icon)
                    .font(.system(size: 60))
                    .foregroundColor(step.color)
                
                Text(step.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(step.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if let action = step.action, let actionText = step.actionText {
                    Button(actionText, action: action)
                        .buttonStyle(.borderedProminent)
                }
            }
            
            Spacer()
            
            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Previous") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if currentStep < steps.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 600, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct OnboardingStep {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: (() -> Void)?
    let actionText: String?
    
    init(title: String, description: String, icon: String, color: Color, action: (() -> Void)? = nil, actionText: String? = nil) {
        self.title = title
        self.description = description
        self.icon = icon
        self.color = color
        self.action = action
        self.actionText = actionText
    }
}

#Preview {
    OnboardingView()
}
