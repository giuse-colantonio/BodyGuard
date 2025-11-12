//
//  FakeCallerListView.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 11/11/25.
//
import SwiftUI

struct FakeCallerListView: View {
    var body: some View {
        // Schermata iniziale: fake call con Accept / Decline
        FakeCallView(caller: FakeCaller(name: "Sconosciuto", avatar: "person.circle.fill"))
    }
}

#Preview {
    ContentView()
}
