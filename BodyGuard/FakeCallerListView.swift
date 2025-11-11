//
//  FakeCallerListView.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 11/11/25.
//
import SwiftUI
import SwiftData
import Contacts

struct FakeCallerListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor(\Contact.lastName),
        SortDescriptor(\Contact.firstName)
    ]) private var contacts: [Contact]

    @State private var searchText = ""
    @State private var showingSystemPicker = false

    // Navigazione programmata dopo l’import
    @State private var navigateToCaller: FakeCaller?

    var body: some View {
        NavigationStack {
            Group {
                if contacts.isEmpty {
                    ContentUnavailableView(
                        "No Contacts",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("Tap + to import from your iPhone Contacts.")
                    )
                } else {
                    List {
                        ForEach(filteredContacts(), id: \.id) { contact in
                            NavigationLink {
                                FakeCallView(caller: makeCaller(from: contact))
                            } label: {
                                HStack(spacing: 12) {
                                    avatarView(for: contact)
                                        .frame(width: 40, height: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contact.fullName.isEmpty ? "Unnamed" : contact.fullName)
                                            .font(.headline)
                                        if !contact.phoneNumber.isEmpty {
                                            Text(contact.phoneNumber)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteAt)
                    }
                }
            }
            .navigationTitle("Fake Callers")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !contacts.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSystemPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Import from Apple Contacts")
                }
            }
            // Picker Apple Contatti (multi-selezione)
            .sheet(isPresented: $showingSystemPicker) {
                ContactPicker { cnContacts in
                    autoImportAndNavigate(cnContacts)
                    showingSystemPicker = false
                } onCancel: {
                    showingSystemPicker = false
                }
            }
            // Navigazione programmata dopo import
            .background(
                NavigationLink(
                    destination: destinationForNavigateToCaller(),
                    isActive: Binding(
                        get: { navigateToCaller != nil },
                        set: { isActive in if !isActive { navigateToCaller = nil } }
                    )
                ) { EmptyView() }
                .hidden()
            )
        }
    }

    // MARK: - Import + Auto-Navigate

    private func autoImportAndNavigate(_ list: [CNContact]) {
        guard !list.isEmpty else { return }

        var newlyAdded: [Contact] = []

        for cn in list {
            let first = cn.givenName
            let last = cn.familyName
            guard let phone = preferredPhoneString(from: cn) else { continue }

            // Deduplica basilare per nome + numeri (solo cifre)
            let isDuplicate = contacts.contains { existing in
                existing.firstName == first &&
                existing.lastName == last &&
                normalizedDigits(existing.phoneNumber) == phone
            }
            if isDuplicate { continue }

            let new = Contact(firstName: first, lastName: last, phoneNumber: phone)
            modelContext.insert(new)
            newlyAdded.append(new)
        }

        guard !newlyAdded.isEmpty else { return }
        try? modelContext.save()

        // Auto-naviga al primo contatto appena importato
        if let firstNew = newlyAdded.first {
            navigateToCaller = makeCaller(from: firstNew)
        }
    }

    private func preferredPhoneString(from cn: CNContact) -> String? {
        // Preferisci etichette "mobile/cell/iPhone"
        if let mobile = cn.phoneNumbers.first(where: { labelIsMobile($0.label) })?.value.stringValue {
            return normalizedDigits(mobile)
        }
        // Altrimenti il primo numero disponibile
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

    private func filteredContacts() -> [Contact] {
        guard !searchText.isEmpty else { return contacts }
        return contacts.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText) ||
            $0.phoneNumber.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func deleteAt(offsets: IndexSet) {
        let filtered = filteredContacts()
        for offset in offsets {
            guard offset < filtered.count else { continue }
            modelContext.delete(filtered[offset])
        }
        try? modelContext.save()
    }

    private func makeCaller(from contact: Contact) -> FakeCaller {
        FakeCaller(
            name: contact.fullName.trimmingCharacters(in: .whitespaces).isEmpty
                ? (contact.phoneNumber.isEmpty ? "Unknown" : contact.phoneNumber)
                : contact.fullName,
            avatar: "person.circle.fill"
        )
    }

    @ViewBuilder
    private func avatarView(for contact: Contact) -> some View {
        let initials = initialsFor(contact: contact)
        if initials.isEmpty {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.blue)
        } else {
            ZStack {
                Circle().fill(Color.blue.opacity(0.15))
                Text(initials)
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
        }
    }

    private func initialsFor(contact: Contact) -> String {
        let f = contact.firstName.trimmingCharacters(in: .whitespaces).first
        let l = contact.lastName.trimmingCharacters(in: .whitespaces).first
        return String([f, l].compactMap { $0 }).uppercased()
    }

    @ViewBuilder
    private func destinationForNavigateToCaller() -> some View {
        if let caller = navigateToCaller {
            FakeCallView(caller: caller)
        } else {
            EmptyView()
        }
    }
}
