import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct ContactsListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @Query(sort: [
        SortDescriptor(\Contact.lastName),
        SortDescriptor(\Contact.firstName)
    ]) private var contacts: [Contact]

    @State private var searchText = ""
    @State private var isAdding = false
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
                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, contact in
                    // Row is a plain view — NOT a Button
                    HStack {
                        Circle()
                            .fill(.blue)
                            .frame(width: 40, height: 40)
                            .overlay(Text(initials(for: contact)).foregroundColor(.white))

                        VStack(alignment: .leading) {
                            Text(contact.fullName)
                                .font(.headline)
                            Text(contact.phoneNumber)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle()) // makes the whole HStack tappable
                    .onTapGesture {
                        call(contact.phoneNumber) // tap = call
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
                            // Delete immediately from swipe
                            context.delete(contact)
                            try? context.save()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteAt) // enables EditButton multi-delete
            }
            .navigationTitle("Contacts")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // Add new contact sheet
            .sheet(isPresented: $isAdding) {
                NavigationStack {
                    ContactFormView { new in
                        context.insert(new)
                        try? context.save()
                        isAdding = false
                    }
                }
            }
            // Edit sheet — controlled explicitly
            .sheet(isPresented: $isEditingSheetPresented) {
                if let contactToEdit = editing {
                    NavigationStack {
                        ContactFormView(contact: contactToEdit) { updated in
                            // copy back changed values to the SwiftData object
                            contactToEdit.firstName = updated.firstName
                            contactToEdit.lastName = updated.lastName
                            contactToEdit.phoneNumber = updated.phoneNumber
                            try? context.save()
                            // close
                            isEditingSheetPresented = false
                            editing = nil
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func deleteAt(offsets: IndexSet) {
        // offsets refer to filtered array indices; map to Contact objects
        for offset in offsets {
            guard offset < filtered.count else { continue }
            let c = filtered[offset]
            context.delete(c)
        }
        try? context.save()
    }

    private func initials(for contact: Contact) -> String {
        let f = contact.firstName.first.map(String.init) ?? ""
        let l = contact.lastName.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }

    private func call(_ number: String) {
        let digits = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "tel://\(digits)") {
            openURL(url)
        }
    }
}
