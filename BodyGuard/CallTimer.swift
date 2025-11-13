//
//  CallTimer.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 11/11/25.
//

import Foundation
import Combine

@MainActor
final class CallTimer: ObservableObject {
    @Published private(set) var elapsed: TimeInterval = 0

    private var timer: Timer?
    private var startDate: Date?

    var formattedTime: String {
        let total = Int(elapsed)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func start() {
        guard timer == nil else { return }
        startDate = Date()
        elapsed = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            
            // --- MODIFICA QUI ---
            // Non serve il Task { @MainActor... } perché siamo già sul MainActor.
            self.elapsed += 1
            // ---------------------
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        startDate = nil
        elapsed = 0
    }
}
