//
//  FakeCallerListView.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 11/11/25.
//
import SwiftUI

struct FakeCallerListView: View {
    @State private var caller: FakeCaller? = nil

    private let names = [
        "Mario Rossi",
        "Giulia Bianchi",
        "Luca Verdi",
        "Sara Neri",
        "Francesco Gallo",
        "Elena Conti",
        "Alessandro Riva",
        "Chiara Moretti",
        "Davide Greco",
        "Federica Leone"
    ]

    var body: some View {
        Group {
            if let caller {
                FakeCallView(caller: caller)
            } else {
                // Placeholder molto leggero mentre scegliamo il nome
                ProgressView().tint(.accentColor)
            }
        }
        .onAppear {
            // Estrae un nome casuale ogni volta che entri nella vista/tab
            let randomName = names.randomElement() ?? "Sconosciuto"
            caller = FakeCaller(name: randomName, avatar: "person.circle.fill")
        }
        .onDisappear {
            // Resetta così al prossimo accesso verrà ricalcolato
            caller = nil
        }
    }
}

#Preview {
    ContentView()
}
