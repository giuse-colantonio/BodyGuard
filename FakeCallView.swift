//
//  FakeCallView.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 11/11/25.
//

import SwiftUI
import AVFoundation

struct FakeCallView: View {
    let caller: FakeCaller
    @StateObject private var model = FakeCallViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Lighter, native-feeling background using system materials
            Rectangle()
                .fill(.thinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 24)

                // Avatar
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: caller.avatar)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70, height: 70)
                            .foregroundStyle(.primary)
                    )
                    .accessibilityHidden(true)

                // Caller name
                Text(caller.name)
                    .font(.system(size: 34, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)

                // Status line (incoming or timer)
                Group {
                    if model.isCalling {
                        Text(model.timer.formattedTime)
                    } else {
                        Text("mobile")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityLabel(model.isCalling ? "Call duration \(model.timer.formattedTime)" : "Incoming call")

                Spacer()

                if model.isCalling {
                    // In-call controls
                    ControlGrid(
                        endAction: { model.endCall() },
                        endLabel: "End",
                        endSymbol: "phone.down.fill",
                        endTint: .red,
                        primaryControls: [
                            .init(title: "Mute", systemImage: "mic.slash.fill"),
                            .init(title: "Keypad", systemImage: "circle.grid.3x3.fill"),
                            .init(title: "Speaker", systemImage: "speaker.wave.3.fill"),
                            .init(title: "Add", systemImage: "plus"),
                            .init(title: "FaceTime", systemImage: "video.fill"),
                            .init(title: "Contacts", systemImage: "person.crop.circle")
                        ]
                    )
                } else {
                    // Incoming call actions
                    IncomingButtons(
                        accept: { model.acceptCall() },
                        decline: {
                            model.declineCall()
                            dismiss()
                        }
                    )
                }

                Spacer(minLength: 16)
            }
            .padding(.horizontal, 24)
        }
        .onDisappear { model.endCall() }
        .statusBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .interactiveDismissDisabled(model.isCalling)
        .accessibilityElement(children: .contain)
    }
}
