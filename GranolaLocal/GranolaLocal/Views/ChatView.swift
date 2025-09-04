import SwiftUI

struct ChatView: View {
    @ObservedObject var note: MeetingNote
    @EnvironmentObject var aiProcessor: AIProcessor
    @EnvironmentObject var notesManager: NotesManager
    
    @State private var messageText = ""
    @State private var isProcessing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingQuickActions = false
    
    private let quickActions = [
        QuickAction(
            title: "List Action Items",
            icon: "checkmark.circle",
            prompt: "Please extract and list all action items, tasks, or follow-up items mentioned in this meeting. Format them as a clear list with who is responsible (if mentioned)."
        ),
        QuickAction(
            title: "Key Decisions",
            icon: "star.circle",
            prompt: "What key decisions were made in this meeting? Please list them clearly with any relevant context or reasoning mentioned."
        ),
        QuickAction(
            title: "Meeting Summary",
            icon: "doc.text",
            prompt: "Provide a brief summary of the main topics and outcomes of this meeting."
        ),
        QuickAction(
            title: "Follow-up Email",
            icon: "envelope",
            prompt: "Draft a professional follow-up email summarizing this meeting that could be sent to participants."
        ),
        QuickAction(
            title: "Who Said What",
            icon: "person.2",
            prompt: "Can you identify the different speakers and what their main contributions were to the discussion?"
        ),
        QuickAction(
            title: "Next Steps",
            icon: "arrow.right.circle",
            prompt: "What are the next steps or actions that need to be taken based on this meeting?"
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Ask AI")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    showingQuickActions.toggle()
                } label: {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.blue)
                }
                .help("Quick actions")
                .popover(isPresented: $showingQuickActions) {
                    QuickActionsView(
                        actions: quickActions,
                        onActionSelected: { action in
                            sendMessage(action.prompt)
                            showingQuickActions = false
                        }
                    )
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(note.chatHistory) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }
                        
                        if isProcessing {
                            TypingIndicatorView()
                                .id("typing")
                        }
                    }
                    .padding()
                }
                .onChange(of: note.chatHistory.count) { _ in
                    withAnimation {
                        proxy.scrollTo(note.chatHistory.last?.id ?? "typing", anchor: .bottom)
                    }
                }
                .onChange(of: isProcessing) { _ in
                    if isProcessing {
                        withAnimation {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input area
            VStack(spacing: 8) {
                if aiProcessor.apiKeyStatus != .valid {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Configure OpenAI API key in Settings to use AI chat")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal)
                }
                
                HStack {
                    TextField("Ask about this meeting...", text: $messageText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .onSubmit {
                            sendMessage(messageText)
                        }
                        .disabled(isProcessing || aiProcessor.apiKeyStatus != .valid)
                    
                    Button {
                        sendMessage(messageText)
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                             isProcessing || 
                             aiProcessor.apiKeyStatus != .valid)
                }
                .padding()
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func sendMessage(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, !isProcessing else { return }
        
        // Add user message
        let userMessage = ChatMessage(content: trimmedText, isUser: true)
        note.chatHistory.append(userMessage)
        
        // Clear input
        messageText = ""
        isProcessing = true
        
        // Save note with new message
        notesManager.saveNote(note)
        
        // Get AI response
        Task {
            do {
                let response = try await aiProcessor.answerQuestion(
                    question: trimmedText,
                    transcript: note.transcript,
                    chatHistory: note.chatHistory
                )
                
                DispatchQueue.main.async {
                    let aiMessage = ChatMessage(content: response, isUser: false)
                    self.note.chatHistory.append(aiMessage)
                    self.notesManager.saveNote(self.note)
                    self.isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.isProcessing = false
                }
            }
        }
    }
}

struct MessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top) {
            if message.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding(12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .frame(maxWidth: 250, alignment: .trailing)
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            } else {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(message.content))
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(16)
                        .frame(maxWidth: 250, alignment: .leading)
                        .textSelection(.enabled)
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
}

struct TypingIndicatorView: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.purple)
                .font(.title2)
            
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(animationPhase == index ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: false), value: animationPhase)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(16)
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    animationPhase = (animationPhase + 1) % 3
                }
            }
            
            Spacer()
        }
    }
}

struct QuickActionsView: View {
    let actions: [QuickAction]
    let onActionSelected: (QuickAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Quick Actions")
                .font(.headline)
                .padding()
            
            Divider()
            
            ForEach(actions, id: \.title) { action in
                Button {
                    onActionSelected(action)
                } label: {
                    HStack {
                        Image(systemName: action.icon)
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        Text(action.title)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Color.clear)
                .onHover { hovering in
                    // Could add hover effect here
                }
                
                if action.title != actions.last?.title {
                    Divider()
                        .padding(.leading, 40)
                }
            }
        }
        .frame(width: 250)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct QuickAction {
    let title: String
    let icon: String
    let prompt: String
}

#Preview {
    ChatView(note: MeetingNote(title: "Sample Meeting"))
        .environmentObject(AIProcessor())
        .environmentObject(NotesManager())
        .frame(width: 350, height: 600)
}
