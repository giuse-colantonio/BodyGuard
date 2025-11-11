//
//  CircleButton.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 11/11/25.
//

import SwiftUI

struct CircleButton: View {
    enum MaterialStyle {
        case none
        case ultraThin
    }

    let symbol: String
    let tint: Color
    let size: CGFloat
    let symbolScale: CGFloat
    var rotate: Double = 0
    var materialStyle: MaterialStyle = .none

    var body: some View {
        ZStack {
            if materialStyle == .ultraThin {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .frame(width: size, height: size)
            } else {
                Circle()
                    .fill(tint)
                    .frame(width: size, height: size)
            }

            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .frame(width: size * symbolScale, height: size * symbolScale)
                .foregroundStyle(materialStyle == .ultraThin ? Color.primary : Color.white)
                .rotationEffect(.degrees(rotate))
        }
        .contentShape(Circle())
        .accessibilityAddTraits(.isButton)
    }
}
