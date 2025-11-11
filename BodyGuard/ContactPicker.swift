//
//  ContactPicker.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 11/11/25.
//

import SwiftUI
import Contacts
import ContactsUI

struct ContactPicker: UIViewControllerRepresentable {
    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPicker

        init(parent: ContactPicker) { self.parent = parent }

        // Multiple selection
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.onSelectMultiple(contacts)
        }

        // Single selection (fallback if user taps a single row)
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onSelectMultiple([contact])
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.onCancel()
        }
    }

    var onSelectMultiple: ([CNContact]) -> Void
    var onCancel: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // Show only people with phone numbers to keep flow simple
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
}
