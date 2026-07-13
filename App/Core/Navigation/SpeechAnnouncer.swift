import AVFoundation

/// German turn-by-turn voice (analog of the TTS block in Android NavigationScreen).
/// QUEUE_FLUSH semantics: a new announcement interrupts the current one. The
/// approach/immediate de-dup latches live in NavigationEngine, not here.
final class SpeechAnnouncer {
    private let synth = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice?
    var enabled = true

    init() {
        voice = AVSpeechSynthesisVoice(language: "de-DE")
            ?? AVSpeechSynthesisVoice(language: "de-CH")
            ?? AVSpeechSynthesisVoice(language: "de")
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .voicePrompt,
                                 options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? session.setActive(true)
    }

    func announce(_ text: String) {
        guard enabled, !text.isEmpty else { return }
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: text)
        u.voice = voice
        synth.speak(u)
    }

    func shutdown() {
        synth.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
