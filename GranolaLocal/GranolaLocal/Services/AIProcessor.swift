import Foundation
import OpenAI

class AIProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var apiKeyStatus: APIKeyStatus = .notSet
    
    private var openAI: OpenAI?
    private let userDefaults = UserDefaults.standard
    private let apiKeyKey = "openai_api_key"
    
    enum APIKeyStatus {
        case notSet
        case valid
        case invalid
        case testing
    }
    
    init() {
        loadAPIKey()
    }
    
    // MARK: - API Key Management
    
    func setAPIKey(_ key: String) {
        userDefaults.set(key, forKey: apiKeyKey)
        loadAPIKey()
    }
    
    func getAPIKey() -> String? {
        return userDefaults.string(forKey: apiKeyKey)
    }
    
    private func loadAPIKey() {
        guard let apiKey = userDefaults.string(forKey: apiKeyKey), !apiKey.isEmpty else {
            apiKeyStatus = .notSet
            openAI = nil
            return
        }
        
        openAI = OpenAI(apiToken: apiKey)
        apiKeyStatus = .valid
    }
    
    func testAPIKey() async {
        guard let openAI = openAI else {
            DispatchQueue.main.async {
                self.apiKeyStatus = .notSet
            }
            return
        }
        
        DispatchQueue.main.async {
            self.apiKeyStatus = .testing
        }
        
        do {
            let query = ChatQuery(
                messages: [
                    Chat(role: .user, content: "Hello")
                ],
                model: .gpt3_5Turbo,
                maxTokens: 5
            )
            
            _ = try await openAI.chats(query: query)
            
            DispatchQueue.main.async {
                self.apiKeyStatus = .valid
                self.errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.apiKeyStatus = .invalid
                self.errorMessage = "Invalid API key: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Note Enhancement
    
    func enhanceNotes(userNotes: String, transcript: String, template: NoteTemplate) async throws -> String {
        guard let openAI = openAI else {
            throw AIError.apiKeyNotSet
        }
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.errorMessage = nil
        }
        
        defer {
            DispatchQueue.main.async {
                self.isProcessing = false
            }
        }
        
        let prompt = createEnhancementPrompt(userNotes: userNotes, transcript: transcript, template: template)
        
        do {
            let query = ChatQuery(
                messages: [
                    Chat(role: .system, content: "You are an AI assistant that helps improve meeting notes. You analyze meeting transcripts and user notes to create comprehensive, well-structured meeting summaries."),
                    Chat(role: .user, content: prompt)
                ],
                model: .gpt4,
                temperature: 0.1,
                maxTokens: 2000
            )
            
            let result = try await openAI.chats(query: query)
            
            guard let content = result.choices.first?.message.content?.string else {
                throw AIError.invalidResponse
            }
            
            return content
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Enhancement failed: \(error.localizedDescription)"
            }
            throw AIError.enhancementFailed(error.localizedDescription)
        }
    }
    
    private func createEnhancementPrompt(userNotes: String, transcript: String, template: NoteTemplate) -> String {
        var prompt = """
        I have a meeting transcript and some notes taken during the meeting. Please help me create enhanced, comprehensive meeting notes.
        
        MEETING TRANSCRIPT:
        \(transcript)
        
        """
        
        if !userNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt += """
            USER'S NOTES (taken during meeting):
            \(userNotes)
            
            """
        }
        
        prompt += """
        INSTRUCTIONS:
        """
        
        if template == .auto {
            prompt += """
            - Create a well-structured summary using the transcript
            - If the user took notes, incorporate and expand on them using details from the transcript
            - Organize the content with clear headings and bullet points
            - Include specific details like names, dates, numbers, and decisions mentioned
            - Create sections for: Summary, Key Points, Decisions Made, and Action Items
            - Use markdown formatting for better readability
            - Keep the tone professional and concise
            - Only include information that was actually discussed in the meeting
            """
        } else {
            prompt += """
            - Structure the notes using this template: \(template.rawValue)
            - Use these sections: \(template.sections.joined(separator: ", "))
            - If the user took notes under any sections, expand on them using the transcript
            - Fill in each section with relevant information from the transcript
            - If a section has no relevant information, you may omit it or note that it wasn't discussed
            - Include specific details like names, dates, numbers, and decisions
            - Use markdown formatting with clear headings
            - Keep the content factual and based only on what was discussed
            """
        }
        
        prompt += """
        
        Please create enhanced meeting notes now:
        """
        
        return prompt
    }
    
    // MARK: - Q&A Chat
    
    func answerQuestion(question: String, transcript: String, chatHistory: [ChatMessage] = []) async throws -> String {
        guard let openAI = openAI else {
            throw AIError.apiKeyNotSet
        }
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.errorMessage = nil
        }
        
        defer {
            DispatchQueue.main.async {
                self.isProcessing = false
            }
        }
        
        // Build conversation context
        var messages: [Chat] = [
            Chat(role: .system, content: """
                You are an AI assistant that answers questions about meeting content. You have access to a meeting transcript and should answer questions based only on information contained in that transcript.
                
                Guidelines:
                - Only use information from the provided transcript
                - If the answer isn't in the transcript, say so clearly
                - Be concise and direct in your responses
                - Include specific quotes or details when relevant
                - If asked about timing, refer to the context in the transcript
                """),
            Chat(role: .user, content: """
                MEETING TRANSCRIPT:
                \(transcript)
                
                Please answer questions about this meeting based on the transcript above.
                """)
        ]
        
        // Add chat history for context
        for message in chatHistory.suffix(10) { // Keep last 10 messages for context
            messages.append(Chat(
                role: message.isUser ? .user : .assistant,
                content: message.content
            ))
        }
        
        // Add current question
        messages.append(Chat(role: .user, content: question))
        
        do {
            let query = ChatQuery(
                messages: messages,
                model: .gpt4,
                temperature: 0.1,
                maxTokens: 500
            )
            
            let result = try await openAI.chats(query: query)
            
            guard let content = result.choices.first?.message.content?.string else {
                throw AIError.invalidResponse
            }
            
            return content
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Q&A failed: \(error.localizedDescription)"
            }
            throw AIError.qaFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Specialized Prompts
    
    func generateActionItems(transcript: String) async throws -> String {
        return try await answerQuestion(
            question: "Please extract and list all action items, tasks, or follow-up items mentioned in this meeting. Format them as a clear list with who is responsible (if mentioned).",
            transcript: transcript
        )
    }
    
    func generateFollowUpEmail(transcript: String, enhancedNotes: String) async throws -> String {
        guard let openAI = openAI else {
            throw AIError.apiKeyNotSet
        }
        
        let prompt = """
        Based on the following meeting notes, please draft a professional follow-up email that could be sent to meeting participants.
        
        MEETING NOTES:
        \(enhancedNotes)
        
        Please create an email that:
        - Summarizes key points briefly
        - Lists any decisions made
        - Includes action items with owners (if specified)
        - Has a professional, friendly tone
        - Uses proper email formatting
        
        Format as a complete email with subject line.
        """
        
        do {
            let query = ChatQuery(
                messages: [
                    Chat(role: .system, content: "You are a professional assistant helping to draft follow-up emails after meetings."),
                    Chat(role: .user, content: prompt)
                ],
                model: .gpt4,
                temperature: 0.2,
                maxTokens: 800
            )
            
            let result = try await openAI.chats(query: query)
            
            guard let content = result.choices.first?.message.content?.string else {
                throw AIError.invalidResponse
            }
            
            return content
            
        } catch {
            throw AIError.emailGenerationFailed(error.localizedDescription)
        }
    }
    
    func identifyKeyDecisions(transcript: String) async throws -> String {
        return try await answerQuestion(
            question: "What key decisions were made in this meeting? Please list them clearly with any relevant context or reasoning mentioned.",
            transcript: transcript
        )
    }
    
    func summarizeDiscussion(transcript: String, topic: String) async throws -> String {
        return try await answerQuestion(
            question: "Can you summarize what was discussed about \(topic) in this meeting? Include key points and any conclusions reached.",
            transcript: transcript
        )
    }
}

// MARK: - Error Types

enum AIError: LocalizedError {
    case apiKeyNotSet
    case invalidResponse
    case enhancementFailed(String)
    case qaFailed(String)
    case emailGenerationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .apiKeyNotSet:
            return "OpenAI API key not configured. Please set your API key in Settings."
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .enhancementFailed(let message):
            return "Note enhancement failed: \(message)"
        case .qaFailed(let message):
            return "Question answering failed: \(message)"
        case .emailGenerationFailed(let message):
            return "Email generation failed: \(message)"
        }
    }
}

// MARK: - Extensions

extension Chat.Role {
    var displayName: String {
        switch self {
        case .user:
            return "You"
        case .assistant:
            return "AI"
        case .system:
            return "System"
        case .function:
            return "Function"
        }
    }
}
