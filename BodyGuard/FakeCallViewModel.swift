//
//  FakeCallViewModel.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 11/11/25.
//
//  *** MODIFICATO PER REALISMO (VOCE, SCRIPT) - RUMORE DI FONDO RIMOSSO ***
//

import Foundation
import SwiftUI
import AVFoundation
import Combine

@MainActor
final class FakeCallViewModel: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    
    // --- Proprietà di Stato (UI) ---
    @Published var isCalling = false
    @Published var timer = CallTimer()

    // --- Proprietà per il TTS ---
    private var synthesizer = AVSpeechSynthesizer()
    private var currentScriptIndex = 0
    
    // Rimossa la proprietà: private var ambiencePlayer: AVAudioPlayer?
    
    private var timerCancellable: AnyCancellable?
    
    // Script "umano" in inglese
    private let callScript: [String] = [
        "Hello?",
        "Oh, hi... can you hear me?",
        "Okay good. Sorry, I... I can't really talk right now.",
        "I'm just calling really quick to tell you I've got that thing.",
        "Yeah... exactly. It's all set.",
        "Okay, I gotta go. See you later, bye."
    ]

    // Configura tutto nell'init
    override init() {
        super.init()
        synthesizer.delegate = self
        
        // Collega il timer
        timerCancellable = timer.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        
        // Configura la sessione audio
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .voiceChat)
            print("Audio session configurata.")
        } catch {
            print("ERRORE: Impossibile configurare AVAudioSession: \(error.localizedDescription)")
        }
        
        // Blocco di codice per l'ambience player RIMOSSO
    }
    
    deinit {
        // Pulisci
        synthesizer.stopSpeaking(at: .immediate)
        // Rimossa chiamata: ambiencePlayer?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        timerCancellable?.cancel()
    }

    // --- Azioni Chiamata ---

    func acceptCall() {
        haptic(.success)
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            print("Audio session attivata.")
        } catch {
            print("ERRORE: Impossibile attivare AVAudioSession: \(error.localizedDescription)")
        }
        
        isCalling = true
        timer.start()
        
        // Rimossa chiamata: ambiencePlayer?.play()
        
        // Avvia la conversazione
        currentScriptIndex = 0
        
        // Aggiungi un piccolo ritardo prima che l'altra persona "risponda"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.speakNextPhrase()
        }
    }

    func declineCall() {
        haptic(.error)
        endCall()
    }

    func endCall() {
        guard isCalling else { return }
        
        isCalling = false
        timer.stop()
        
        // Ferma tutto
        synthesizer.stopSpeaking(at: .immediate)
        // Rimossa chiamata: ambiencePlayer?.stop()
        
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            try? AVAudioSession.sharedInstance().setActive(false)
            print("Audio session disattivata.")
        }
    }

    // --- Logica Interna TTS ---

    private func speakNextPhrase() {
        guard currentScriptIndex < callScript.count else {
            print("Conversazione finita.")
            return
        }

        let text = callScript[currentScriptIndex]
        let utterance = AVSpeechUtterance(string: text)
        
        // Seleziona una voce specifica (non default)
        let voiceIdentifier = "com.apple.speech.synthesis.voice.Zoe.premium" // "Zoe (Premium)"
        
        if let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        } else {
            print("Voce 'Zoe Premium' non trovata, uso il default en-US.")
            // Fallback alla voce standard
            utterance.voice = AVSpeechSynthesisVoice.speechVoices()
                .first(where: { $0.language == "en-US" && $0.quality == .enhanced })
            ?? AVSpeechSynthesisVoice(language: "en-US")
        }
        
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95 // Leggermente più lenta
        utterance.pitchMultiplier = 0.9 // Leggermente più bassa
        
        // Aggiungi un ritardo *prima* della frase, per simulare il tempo di "pensiero"
        utterance.preUtteranceDelay = TimeInterval.random(in: 0.1...0.4)

        synthesizer.speak(utterance)
        currentScriptIndex += 1
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // La pausa tra le frasi ora è più lunga e variabile
        let randomPause = TimeInterval.random(in: 1.5...3.5)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + randomPause) {
            if self.isCalling {
                self.speakNextPhrase()
            }
        }
    }

    // --- Helpers ---

    private func haptic(_ style: UINotificationFeedbackGenerator.FeedbackType) {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(style)
    }
}
