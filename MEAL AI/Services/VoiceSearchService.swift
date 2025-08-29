import Foundation
import Speech
import AVFoundation

final class VoiceSearchService: NSObject, ObservableObject {
    static let shared = VoiceSearchService()
    private override init() {}

    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    func authorize() async throws {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status != .authorized {
            let granted: Bool = await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { s in
                    cont.resume(returning: s == .authorized)
                }
            }
            if !granted {
                throw NSError(domain: "Voice", code: -2, userInfo: [NSLocalizedDescriptionKey: "Speech denied"])
            }
        }

        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted: break
        case .denied:
            throw NSError(domain: "Voice", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mic denied"])
        case .undetermined:
            let granted: Bool = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { ok in
                    cont.resume(returning: ok)
                }
            }
            if !granted {
                throw NSError(domain: "Voice", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mic denied"])
            }
        @unknown default: break
        }
    }

    func start(onUpdate: @escaping (String)->Void) throws {
        stop()

        let node = audioEngine.inputNode
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { throw NSError(domain: "Voice", code: -3, userInfo: [NSLocalizedDescriptionKey: "No request"]) }
        request.shouldReportPartialResults = true

        task = recognizer?.recognitionTask(with: request) { result, error in
            if let t = result?.bestTranscription.formattedString { onUpdate(t) }
            if result?.isFinal == true || error != nil {
                self.stop()
            }
        }

        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buf, _ in
            self.request?.append(buf)
        }
        try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
        try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        audioEngine.prepare()
        try audioEngine.start()
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil; task = nil
    }
}
