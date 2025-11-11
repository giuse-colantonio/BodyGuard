import SwiftUI
import SwiftData
import Contacts

@available(iOS 26.0, *)
struct ContactsListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @Query(sort: [
        SortDescriptor(\Contact.lastName),
        SortDescriptor(\Contact.firstName)
    ]) private var contacts: [Contact]

    @State private var searchText = ""
    @State private var showingSystemPicker = false
    @State private var editing: Contact? = nil
    @State private var isEditingSheetPresented = false

    private var filtered: [Contact] {
        if searchText.isEmpty { return contacts }
        return contacts.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText) ||
            $0.phoneNumber.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { _, contact in
                    HStack {
                        Circle()
                            .fill(.blue)
                            .frame(width: 40, height: 40)
                            .overlay(Text(initials(for: contact)).foregroundColor(.white))

                        VStack(alignment: .leading) {
                            Text(contact.fullName.isEmpty ? "Unnamed" : contact.fullName)
                                .font(.headline)
                            if !contact.phoneNumber.isEmpty {
                                Text(contact.phoneNumber)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        call(contact.phoneNumber)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            editing = contact
                            isEditingSheetPresented = true
                        } label: {
                            VStack {
                                Image(systemName: "pencil")
                                Text("Edit")
                                    .font(.caption2)
                            }
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange))
                            .foregroundColor(.white)
                        }

                        Button(role: .destructive) {
                            context.delete(contact)
                            try? context.save()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteAt)
            }
            .navigationTitle("Contacts")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSystemPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Import from Apple Contacts")
                }
            }
            // Apple Contacts picker (multi-select)
            .sheet(isPresented: $showingSystemPicker) {
                ContactPicker { cnContacts in
                    importCNContacts(cnContacts)
                    showingSystemPicker = false
                } onCancel: {
                    showingSystemPicker = false
                }
            }
            // Edit sheet — mantiene la modifica in‑app dei contatti già importati
            .sheet(isPresented: $isEditingSheetPresented) {
                if let contactToEdit = editing {
                    NavigationStack {
                        ContactFormView(contact: contactToEdit) { updated in
                            contactToEdit.firstName = updated.firstName
                            contactToEdit.lastName = updated.lastName
                            contactToEdit.phoneNumber = updated.phoneNumber
                            try? context.save()
                            isEditingSheetPresented = false
                            editing = nil
                        }
                    }
                }
            }
        }
    }

    // MARK: - Import da Apple Contacts

    private func importCNContacts(_ list: [CNContact]) {
        guard !list.isEmpty else { return }

        for cn in list {
            let first = cn.givenName
            let last = cn.familyName
            guard let phone = preferredPhoneString(from: cn) else { continue }

            // Deduplica semplice: nome + numero (solo cifre)
            let exists = contacts.contains { c in
                c.firstName == first &&
                c.lastName == last &&
                normalizedDigits(c.phoneNumber) == phone
            }
            if exists { continue }

            let new = Contact(firstName: first, lastName: last, phoneNumber: phone)
            context.insert(new)
        }
        try? context.save()
    }

    private func preferredPhoneString(from cn: CNContact) -> String? {
        if let mobile = cn.phoneNumbers.first(where: { labelIsMobile($0.label) })?.value.stringValue {
            return normalizedDigits(mobile)
        }
        if let any = cn.phoneNumbers.first?.value.stringValue {
            return normalizedDigits(any)
        }
        return nil
    }

    private func labelIsMobile(_ label: String?) -> Bool {
        guard let label else { return false }
        let l = label.lowercased()
        return l.contains("mobile") || l.contains("cell") || l.contains("iphone")
    }

    private func normalizedDigits(_ raw: String) -> String {
        raw.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }

    // MARK: - Helpers

    private func deleteAt(offsets: IndexSet) {
        for offset in offsets {
            guard offset < filtered.count else { continue }
            context.delete(filtered[offset])
        }
        try? context.save()
    }

    private func initials(for contact: Contact) -> String {
        let f = contact.firstName.first.map(String.init) ?? ""
        let l = contact.lastName.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }

    private func call(_ number: String) {
        let digits = normalizedDigits(number)
        if let url = URL(string: "tel://\(digits)") {
            openURL(url)
        }
    }
}
