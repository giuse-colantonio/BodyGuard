//
//  FakeCallViewModel.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 11/11/25.
//

import Foundation
import SwiftUI
import AVFoundation
import Combine

@MainActor
final class FakeCallViewModel: ObservableObject {
    @Published var isCalling = false
    @Published var timer = CallTimer()
    let voiceManager = VoiceManager()

    func acceptCall() {
        haptic(.success)
        isCalling = true
        timer.start()
        voiceManager.playSample()
    }

    func declineCall() {
        haptic(.error)
        endCall()
    }

    func endCall() {
        isCalling = false
        timer.stop()
        voiceManager.stop()
    }

    private func haptic(_ style: UINotificationFeedbackGenerator.FeedbackType) {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(style)
    }
}
