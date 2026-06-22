import Foundation
import Speech
import AVFoundation

// Tracks keyboard extension full access status (shared)
public struct FullAccessStatus {
    public static var isFullAccessGranted: Bool = false
}

final class SpeechRecognizerService: NSObject {
    private static let audioQueueKey = DispatchSpecificKey<String>()
    
    private var audioEngine: AVAudioEngine? = nil
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?
    
    private let audioQueue = DispatchQueue(label: "com.versekey.audioQueue")
    private enum State { case idle, starting, listening, stopping }
    private var state: State = .idle
    
    override init() {
        self.recognizer = SFSpeechRecognizer()
        super.init()
        audioQueue.setSpecific(key: Self.audioQueueKey, value: "audioQueue")
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func configureAudioSession(mode: AVAudioSession.Mode = .measurement) throws {
        let session = AVAudioSession.sharedInstance()
        // First, ensure the session is inactive before reconfiguring
        _ = try? session.setActive(false, options: .notifyOthersOnDeactivation)

        // Prefer a recording-only category to avoid conflicts with other audio apps
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetoothHFP])
        } catch {
            // Fallback to playAndRecord if .record fails in this environment
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .allowBluetoothHFP])
        }

        // Tune IO for lower latency and better stability
        _ = try? session.setPreferredSampleRate(44_100)
        _ = try? session.setPreferredIOBufferDuration(0.005)

        // Activate the session; prefer notifying others so they can yield
        do {
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
        } catch {
            // Brief backoff then final retry
            usleep(150_000)
            do {
                try session.setActive(true, options: [.notifyOthersOnDeactivation])
            } catch {
                throw error
            }
        }
    }
    
    private func hasUsageDescriptionKeys() -> (ok: Bool, missing: [String]) {
        let bundle = Bundle.main
        let required = ["NSSpeechRecognitionUsageDescription", "NSMicrophoneUsageDescription"]
        var missing: [String] = []
        for key in required {
            if bundle.object(forInfoDictionaryKey: key) == nil {
                missing.append(key)
            }
        }
        return (missing.isEmpty, missing)
    }
    
    private func stopRecognitionAndEngine(deactivateSession: Bool) {
        print("[Speech] stopRecognitionAndEngine(deactivate: \(deactivateSession))")
        if let task = recognitionTask { print("[Speech] Cancelling recognitionTask") ; task.cancel() }
        recognitionTask = nil
        if let req = request { print("[Speech] Ending request audio") ; req.endAudio() }
        request = nil
        if let engine = audioEngine {
            print("[Speech] Removing tap, stopping engine")
            engine.inputNode.removeTap(onBus: 0)
            if engine.isRunning { engine.stop() }
            engine.reset()
        }
        audioEngine = nil
        if deactivateSession {
            print("[Speech] Deactivating AVAudioSession")
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        state = .idle
    }
    
    func start(onPartial: @escaping (String) -> Void, onFinal: @escaping (String) -> Void, onError: @escaping (Error) -> Void) {
        print("[Speech] start() called")
        // Single-flight guard: if not idle, stop first then proceed
        if state != .idle {
            print("[Speech] start() called while state=\(state). Stopping first…")
            stopRecognitionAndEngine(deactivateSession: true)
        }
        // In keyboard extension, voice input is disabled entirely
        #if !os(macOS)
        if Bundle.main.bundlePath.hasSuffix(".appex") {
            // Voice is disabled in the keyboard extension to ensure reliability across host apps
            onError(NSError(domain: "Speech", code: -12, userInfo: [NSLocalizedDescriptionKey: "Voice input isn’t available in this keyboard. Type your reference."]))
            return
        }
        #endif
        
        // Ensure Info.plist contains required privacy usage description keys to avoid crash
        let check = hasUsageDescriptionKeys()
        if !check.ok {
            let message = "Missing Info.plist keys: " + check.missing.joined(separator: ", ") + ". Add usage descriptions to the target's Info.plist."
            onError(NSError(domain: "Speech", code: -10, userInfo: [NSLocalizedDescriptionKey: message]))
            return
        }
        
        // Check recognizer availability early
        guard let recognizer = self.recognizer else {
            onError(NSError(domain: "Speech", code: 0, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available for current locale"]))
            return
        }
        if !recognizer.isAvailable {
            onError(NSError(domain: "Speech", code: 0, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer currently unavailable"]))
            return
        }
        
        // Request Speech permission first
        SFSpeechRecognizer.requestAuthorization { status in
            print("[Speech] Speech auth status: \(status.rawValue)")
            DispatchQueue.main.async {
                guard status == .authorized else {
                    print("[Speech] Speech permission denied: \(status)")
                    onError(NSError(domain: "Speech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech permission denied"]))
                    return
                }
                
                // Request microphone permission
                let handleMicPermission: (Bool) -> Void = { granted in
                    print("[Speech] Mic permission granted: \(granted)")
                    DispatchQueue.main.async {
                        guard granted else {
                            onError(NSError(domain: "Speech", code: 3, userInfo: [NSLocalizedDescriptionKey: "Microphone access denied"]))
                            return
                        }
                        // Configure audio session
                        do {
                            try self.configureAudioSession(mode: .measurement)
                            print("[Speech] Audio session configured. Dispatching to audioQueue…")
                        } catch {
                            onError(error)
                            return
                        }
                        self.audioQueue.async {
                            self.startSession(onPartial: onPartial, onFinal: onFinal, onError: onError)
                        }
                    }
                }
                if #available(iOS 17.0, *) {
                    AVAudioApplication.requestRecordPermission(completionHandler: handleMicPermission)
                } else {
                    AVAudioSession.sharedInstance().requestRecordPermission(handleMicPermission)
                }
            }
        }
    }
    
    func stop() {
        print("[Speech] stop() called")
        state = .stopping
        stopRecognitionAndEngine(deactivateSession: true)
    }
    
    private func startSession(onPartial: @escaping (String) -> Void, onFinal: @escaping (String) -> Void, onError: @escaping (Error) -> Void) {
        // Ensure we run on the audio queue using a static key
        if DispatchQueue.getSpecific(key: Self.audioQueueKey) == nil {
            return audioQueue.async { [weak self] in
                self?.startSession(onPartial: onPartial, onFinal: onFinal, onError: onError)
            }
        }
        
        if state == .starting || state == .listening { return }
        state = .starting
        print("[Speech] startSession begin on audioQueue")
        defer { state = .idle }
        
        print("[Speech] Ensuring clean start: stopping any existing engine/task")
        stopRecognitionAndEngine(deactivateSession: false)
        audioEngine?.reset()
        usleep(150_000) // 150ms cooldown to avoid RemoteIO race
        print("[Speech] Audio engine reset and cooldown complete")
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request
        print("[Speech] Created SFSpeechAudioBufferRecognitionRequest")
        
        guard let recognizer = recognizer, recognizer.isAvailable else {
            DispatchQueue.main.async {
                onError(NSError(domain: "Speech", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"]))
            }
            return
        }
        
        // Attempt matrix: A) playAndRecord + spokenAudio, B) playAndRecord + voiceChat, C) record + measurement
        let session = AVAudioSession.sharedInstance()
        struct AttemptCfg { let category: AVAudioSession.Category; let mode: AVAudioSession.Mode; let options: AVAudioSession.CategoryOptions; let label: String }
        let attempts: [AttemptCfg] = [
            .init(category: .playAndRecord, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers, .allowBluetoothHFP, .defaultToSpeaker], label: "A"),
            .init(category: .playAndRecord, mode: .voiceChat,   options: [.mixWithOthers,              .allowBluetoothHFP, .defaultToSpeaker], label: "B"),
            .init(category: .record,       mode: .measurement, options: [.mixWithOthers, .duckOthers, .allowBluetoothHFP],                    label: "C")
        ]

        var engineStarted = false
        var lastStartError: NSError? = nil
        var lastInputUnavailable = false

        for (idx, cfg) in attempts.enumerated() {
            // Hard reset session before each attempt
            _ = try? session.setActive(false, options: [.notifyOthersOnDeactivation])
            usleep(120_000) // 120ms cooldown
            do {
                try session.setCategory(cfg.category, mode: cfg.mode, options: cfg.options)
                _ = try? session.setPreferredSampleRate(44_100)
                _ = try? session.setPreferredIOBufferDuration(0.007)
                // Prefer built-in mic if present
                if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                    try? session.setPreferredInput(builtIn)
                    print("[Speech] Preferred input set to builtInMic: \(builtIn.portName)")
                }
                try session.setActive(true, options: [.notifyOthersOnDeactivation])
            } catch {
                print("[Speech] [\(cfg.label)] Session configure failed: \(error)")
                continue
            }

            // Route diagnostics
            let route = session.currentRoute
            let inputsDesc = route.inputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ", ")
            let outputsDesc = route.outputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ", ")
            print("[Speech] Attempt \(cfg.label) cat=\(cfg.category.rawValue) mode=\(cfg.mode.rawValue) opts=\(cfg.options) isInputAvailable=\(session.isInputAvailable) inputs=[\(inputsDesc)] outputs=[\(outputsDesc)]")

            guard session.isInputAvailable, !route.inputs.isEmpty else {
                lastInputUnavailable = true
                lastStartError = NSError(domain: "Speech", code: -20, userInfo: [NSLocalizedDescriptionKey: "Input not available"])
                _ = try? session.setActive(false, options: [.notifyOthersOnDeactivation])
                usleep(idx == 0 ? 240_000 : (idx == 1 ? 320_000 : 400_000))
                continue
            }

            // Fresh engine per attempt
            let newEngine = AVAudioEngine()
            self.audioEngine = newEngine

            let inputNode = newEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.request?.append(buffer)
            }
            print("[Speech] Installed audio tap (attempt \(cfg.label))")

            newEngine.prepare()
            do {
                try newEngine.start()
                print("[Speech] Audio engine started (attempt \(cfg.label))")
                engineStarted = true
                state = .listening
                break
            } catch {
                let nsErr = error as NSError
                lastStartError = nsErr
                print("[Speech] audioEngine.start() failed (attempt \(cfg.label)) code=\(nsErr.code)")
                // Cleanup this attempt
                inputNode.removeTap(onBus: 0)
                newEngine.stop()
                newEngine.reset()
                self.audioEngine = nil
                _ = try? session.setActive(false, options: [.notifyOthersOnDeactivation])
                usleep(idx == 0 ? 240_000 : (idx == 1 ? 320_000 : 400_000))
                continue
            }
        }

        if !engineStarted {
            DispatchQueue.main.async {
                let code = lastStartError?.code ?? -1
                let message: String
                if lastInputUnavailable || code == 2003329396 {
                    message = "Voice input isn’t available in this app. Try Messages/Notes, or type your reference."
                } else {
                    message = "Microphone is in use by another app or a call. Try again after stopping voice recordings or calls."
                }
                onError(NSError(domain: "Speech", code: code, userInfo: [NSLocalizedDescriptionKey: message]))
            }
            return
        }
        
        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let error = error as NSError? {
                // Ignore cancellation errors silently
                if error.domain == NSURLErrorDomain || error.code == NSUserCancelledError { return }
                DispatchQueue.main.async { onError(error) }
                return
            }
            guard let result = result else { return }
            if result.isFinal {
                print("[Speech] Final: \(result.bestTranscription.formattedString)")
                DispatchQueue.main.async {
                    onFinal(result.bestTranscription.formattedString)
                    self.state = .stopping
                    self.stop()
                }
            } else {
                print("[Speech] Partial: \(result.bestTranscription.formattedString)")
                DispatchQueue.main.async {
                    onPartial(result.bestTranscription.formattedString)
                }
            }
        }
        print("[Speech] recognitionTask created")
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            if type == .began {
                print("[Speech] Interruption began — stopping engine")
                self.stopRecognitionAndEngine(deactivateSession: false)
                self.state = .idle
            }
        }
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        // For now, just stop cleanly; user can re-tap to start
        audioQueue.async { [weak self] in
            print("[Speech] Route change — stopping engine")
            self?.stopRecognitionAndEngine(deactivateSession: false)
        }
    }
}
