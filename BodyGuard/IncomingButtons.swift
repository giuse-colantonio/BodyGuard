//
//  IncomingButtons.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 11/11/25.
//

import SwiftUI

struct IncomingButtons: View {
    var accept: () -> Void
    var decline: () -> Void

    var body: some View {
        HStack(spacing: 48) {
            VStack(spacing: 8) {
                CircleButton(
                    symbol: "phone.down.fill",
                    tint: .red,
                    size: 72,
                    symbolScale: 0.48,
                    rotate: 135
                )
                .onTapGesture(perform: decline)
                .accessibilityLabel("Decline")

                Text("Decline")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                CircleButton(
                    symbol: "phone.fill",
                    tint: .green,
                    size: 72,
                    symbolScale: 0.48
                )
                .onTapGesture(perform: accept)
                .accessibilityLabel("Accept")

                Text("Accept")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
