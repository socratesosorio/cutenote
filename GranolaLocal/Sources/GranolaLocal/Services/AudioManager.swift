import Foundation
import AVFoundation
import Combine

class AudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0.0
    @Published var errorMessage: String?
    @Published var availableInputDevices: [AVAudioDevice] = []
    @Published var selectedInputDevice: AVAudioDevice?
    
    private var audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingTimer: Timer?
    private var startTime: Date?
    private var levelTimer: Timer?
    
    // Audio format for recording (16kHz for Whisper compatibility)
    private let recordingFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
    
    override init() {
        super.init()
        setupAudioSession()
        discoverAudioDevices()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            // Request microphone permission
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    DispatchQueue.main.async {
                        if !granted {
                            self.errorMessage = "Microphone access denied. Please enable it in System Preferences."
                        }
                    }
                }
            case .denied, .restricted:
                DispatchQueue.main.async {
                    self.errorMessage = "Microphone access denied. Please enable it in System Preferences."
                }
            case .authorized:
                break
            @unknown default:
                break
            }
        }
    }
    
    // MARK: - Device Discovery
    
    private func discoverAudioDevices() {
        var devices: [AVAudioDevice] = []
        
        // Get all available audio input devices
        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Get default input device
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                     &propertyAddress,
                                     0,
                                     nil,
                                     &propertySize,
                                     &deviceID) == noErr {
            
            if let device = createAudioDevice(from: deviceID) {
                devices.append(device)
            }
        }
        
        // Get all input devices
        propertyAddress.mSelector = kAudioHardwarePropertyDevices
        var deviceCount: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                      &propertyAddress,
                                      0,
                                      nil,
                                      &deviceCount)
        
        let deviceListSize = Int(deviceCount) / MemoryLayout<AudioDeviceID>.size
        var deviceList = [AudioDeviceID](repeating: 0, count: deviceListSize)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                  &propertyAddress,
                                  0,
                                  nil,
                                  &deviceCount,
                                  &deviceList)
        
        for deviceID in deviceList {
            if let device = createAudioDevice(from: deviceID), device.hasInputStreams {
                devices.append(device)
            }
        }
        
        DispatchQueue.main.async {
            self.availableInputDevices = Array(Set(devices)) // Remove duplicates
            self.selectedInputDevice = devices.first
        }
    }
    
    private func createAudioDevice(from deviceID: AudioDeviceID) -> AVAudioDevice? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var propertySize: UInt32 = 0
        AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &propertySize)
        
        var deviceName = [CChar](repeating: 0, count: Int(propertySize))
        if AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &deviceName) == noErr {
            let name = String(cString: deviceName)
            
            // Check if device has input streams
            propertyAddress.mSelector = kAudioDevicePropertyStreams
            propertyAddress.mScope = kAudioDevicePropertyScopeInput
            var streamCount: UInt32 = 0
            AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &streamCount)
            
            return AVAudioDevice(id: deviceID, name: name, hasInputStreams: streamCount > 0)
        }
        
        return nil
    }
    
    // MARK: - Recording Control
    
    func startRecording(for note: MeetingNote) async throws -> URL {
        guard !isRecording else {
            throw AudioError.alreadyRecording
        }
        
        // Create recording URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("GranolaLocal/Recordings")
        
        try FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        
        let filename = "\(note.title.sanitizedForFilename())_\(Int(Date().timeIntervalSince1970)).wav"
        let recordingURL = recordingsPath.appendingPathComponent(filename)
        
        do {
            // Configure audio engine
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            
            // Create audio file for recording
            audioFile = try AVAudioFile(forWriting: recordingURL, settings: recordingFormat.settings)
            
            // Install tap on input node
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                guard let self = self, let audioFile = self.audioFile else { return }
                
                do {
                    // Convert to recording format if needed
                    if inputFormat != self.recordingFormat {
                        let converter = AVAudioConverter(from: inputFormat, to: self.recordingFormat)!
                        let convertedBuffer = AVAudioPCMBuffer(pcmFormat: self.recordingFormat, frameCapacity: buffer.frameCapacity)!
                        
                        var error: NSError?
                        converter.convert(to: convertedBuffer, error: &error) { _, _ in
                            return buffer
                        }
                        
                        if error == nil {
                            try audioFile.write(from: convertedBuffer)
                        }
                    } else {
                        try audioFile.write(from: buffer)
                    }
                    
                    // Update audio level for UI
                    DispatchQueue.main.async {
                        self.updateAudioLevel(from: buffer)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "Recording error: \(error.localizedDescription)"
                    }
                }
            }
            
            // Start the audio engine
            try audioEngine.start()
            
            // Update state
            DispatchQueue.main.async {
                self.isRecording = true
                self.startTime = Date()
                self.errorMessage = nil
                self.startTimers()
            }
            
            return recordingURL
            
        } catch {
            throw AudioError.recordingFailed(error.localizedDescription)
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Close audio file
        audioFile = nil
        
        // Stop timers
        stopTimers()
        
        // Update state
        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
        }
    }
    
    // MARK: - Timer Management
    
    private func startTimers() {
        // Duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            DispatchQueue.main.async {
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func stopTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0.0
        
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(frameLength)
        audioLevel = min(average * 10, 1.0) // Scale and clamp
    }
    
    // MARK: - Device Selection
    
    func selectInputDevice(_ device: AVAudioDevice) {
        selectedInputDevice = device
        // Note: Actual device switching would require more complex CoreAudio setup
        // For now, we'll use the default device but store the selection
    }
}

// MARK: - Supporting Types

struct AVAudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let hasInputStreams: Bool
    
    static func == (lhs: AVAudioDevice, rhs: AVAudioDevice) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum AudioError: LocalizedError {
    case alreadyRecording
    case recordingFailed(String)
    case noMicrophonePermission
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording is already in progress"
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .noMicrophonePermission:
            return "Microphone permission required"
        }
    }
}

// MARK: - String Extension

extension String {
    func sanitizedForFilename() -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":\\/<>|?*")
        return self.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}
