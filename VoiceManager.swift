//
//  VoiceManager.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 11/11/25.
//

import Foundation
import SwiftUI
import AVFoundation
import Combine

final class VoiceManager: ObservableObject {
    @Published var pitch: Float = 1.0

    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    private var pitchControl = AVAudioUnitTimePitch()

    func playSample() {
        guard let url = Bundle.main.url(forResource: "sample_call", withExtension: "mp3") else {
            print("⚠️ Missing sample_call.mp3 in bundle")
            return
        }

        stop()

        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        pitchControl = AVAudioUnitTimePitch()
        pitchControl.rate = 1.0
        pitchControl.pitch = (pitch - 1.0) * 1000

        engine.attach(player)
        engine.attach(pitchControl)
        engine.connect(player, to: pitchControl, format: nil)
        engine.connect(pitchControl, to: engine.mainMixerNode, format: nil)

        do {
            let audioFile = try AVAudioFile(forReading: url)
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()

            player.scheduleFile(audioFile, at: nil)
            player.play()
        } catch {
            print("Audio playback error: \\(error.localizedDescription)")
        }
    }

    func stop() {
        player.stop()
        engine.stop()
    }
}
