//
//  ControlGrid.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 11/11/25.
//

import SwiftUI

struct ControlGrid: View {
    struct Control: Identifiable {
        let id = UUID()
        let title: String
        let systemImage: String
    }

    var endAction: () -> Void
    var endLabel: String
    var endSymbol: String
    var endTint: Color

    var primaryControls: [Control]

    var body: some View {
        VStack(spacing: 28) {
            // 3 x 2 grid of circular controls
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: 3), spacing: 24) {
                ForEach(primaryControls) { control in
                    VStack(spacing: 8) {
                        CircleButton(
                            symbol: control.systemImage,
                            tint: .clear,
                            size: 72,
                            symbolScale: 0.5,
                            materialStyle: .ultraThin
                        )
                        .accessibilityLabel(control.title)

                        Text(control.title)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }

            // End button
            VStack(spacing: 8) {
                CircleButton(symbol: endSymbol, tint: endTint, size: 84, symbolScale: 0.5)
                    .onTapGesture(perform: endAction)
                    .accessibilityLabel(endLabel)
                Text(endLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 12)
    }
}
