//
//  FakeCallerListView.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 11/11/25.
//
import SwiftUI

@available(iOS 26.0, *)
struct FakeCallerListView: View {
    @State private var callers: [FakeCaller] = [
        .init(name: "Alex Rivera", avatar: "person.circle.fill"),
        .init(name: "Boss", avatar: "briefcase.fill"),
        .init(name: "Mom", avatar: "person.crop.circle.badge.checkmark"),
        .init(name: "Unknown", avatar: "questionmark.circle.fill")
    ]

    var body: some View {
        NavigationStack {
            List(callers) { caller in
                NavigationLink(destination: FakeCallView(caller: caller)) {
                    HStack {
                        Image(systemName: caller.avatar)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundStyle(.blue)
                        Text(caller.name)
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Fake Callers")
        }
    }
}

