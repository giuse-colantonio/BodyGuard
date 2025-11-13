//
//  VoiceManager.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 11/11/25.
//
//  Modificato per usare AVSpeechSynthesizer (Text-to-Speech)
//

import Foundation
import SwiftUI
import AVFoundation
import Combine

// 1. Rendi la classe un NSObject e aggiungi il delegato AVSpeechSynthesizerDelegate
final class VoiceManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    
    @Published var pitch: Float = 1.0 // Va da 0.5 (basso) a 2.0 (alto)

    // 2. Sostituisci l'engine con il sintetizzatore
    private var synthesizer = AVSpeechSynthesizer()
    
    // 3. Aggiungi variabili per gestire la "conversazione"
    private var conversationScript: [String] = []
    private var currentScriptIndex = 0
    private var languageCode: String = "it-IT" // Default in italiano

    override init() {
        super.init()
        // 4. Imposta il delegato
        self.synthesizer.delegate = self
    }

    // 5. Rinominiamo 'playSample' in 'startConversation' per chiarezza
    func startConversation(script: [String], language: String = "it-IT") {
        // Assicurati che l'audio possa essere riprodotto
        do {
            // Usiamo .voiceChat per un suono più "telefonico" e per permettere l'output dall'altoparlante auricolare
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .voiceChat)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error.localizedDescription)")
            return
        }

        stop() // Ferma qualsiasi conversazione precedente

        self.conversationScript = script
        self.currentScriptIndex = 0
        self.languageCode = language
        
        speakNextPhrase()
    }

    private func speakNextPhrase() {
        guard currentScriptIndex < conversationScript.count else {
            // Conversazione finita
            print("Conversazione finita.")
            stop()
            return
        }

        let text = conversationScript[currentScriptIndex]
        let utterance = AVSpeechUtterance(string: text)

        // 6. Configura la voce
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        
        // 7. Usa il tuo @Published var per il pitch!
        utterance.pitchMultiplier = pitch

        // 8. Imposta la velocità (CORREZIONE APPLICATA QUI)
        // Questa è la costante corretta.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        // 9. Fai parlare il sintetizzatore
        print("Parlando: \(text)")
        synthesizer.speak(utterance)
        
        currentScriptIndex += 1
    }

    func stop() {
        // 10. Aggiorna la funzione stop
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        conversationScript.removeAll()
        currentScriptIndex = 0
        
        // Puoi decidere se disattivare la sessione audio qui o lasciarla attiva
        // finché la FakeCallView è visibile. Lasciarla attiva evita click udibili.
        // try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    // 11. Questo metodo viene chiamato quando una frase è finita
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("Finito di parlare: \(utterance.speechString)")
        
        // Aggiungi una pausa "realistica" prima della frase successiva
        // Ad esempio, da 1 a 3 secondi
        let randomPause = TimeInterval.random(in: 1.0...3.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + randomPause) {
            // Controlla che nel frattempo l'utente non abbia chiuso la chiamata
            if !self.conversationScript.isEmpty {
                self.speakNextPhrase()
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("Conversazione cancellata.")
        // Non fare nulla, la funzione stop() ha già pulito tutto.
    }
}
