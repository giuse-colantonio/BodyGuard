//
//  ContactFormView.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 10/11/25.
//
import SwiftUI
import SwiftData

struct ContactFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var temp: Contact
    var onSave: (Contact) -> Void

    init(contact: Contact? = nil, onSave: @escaping (Contact) -> Void) {
        if let contact {
            _temp = State(initialValue: Contact(id: contact.id,
                                                firstName: contact.firstName,
                                                lastName: contact.lastName,
                                                phoneNumber: contact.phoneNumber,
                                                createdAt: contact.createdAt))
        } else {
            _temp = State(initialValue: Contact(firstName: "", lastName: "", phoneNumber: ""))
        }
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("First name", text: $temp.firstName)
                TextField("Last name", text: $temp.lastName)
            }
            Section("Phone") {
                TextField("Phone number", text: $temp.phoneNumber)
                    .keyboardType(.phonePad)
            }
        }
        .navigationTitle(temp.fullName.isEmpty ? "New Contact" : temp.fullName)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(temp)
                    dismiss()
                }
                .disabled(temp.firstName.isEmpty && temp.lastName.isEmpty)
            }
        }
    }
}

