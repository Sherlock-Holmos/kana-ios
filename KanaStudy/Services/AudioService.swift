import Foundation
import AVFoundation

/// AudioService — wraps AVSpeechSynthesizer for kana/vocab/sentence playback,
/// and AVPlayer for fixed audio URLs (Audio 3.0 layer).
final class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()

    @Published private(set) var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVPlayer?

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            print("AudioSession config failed: \(error)")
        }
    }

    // MARK: - Speech

    func speak(text: String, language: String = "ja-JP", rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        stop()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = rate
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0.15
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        player?.pause()
        player = nil
        isSpeaking = false
    }
}

extension AudioService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
        }
    }
}