import SwiftUI

struct AddPersonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phoneNumber = ""
    @State private var email = ""

    var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                }

                Section("Contact Info (Optional)") {
                    TextField("Phone Number", text: $phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addPerson()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func addPerson() {
        let person = Person(
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            email: email.isEmpty ? nil : email,
            source: .appLocal
        )
        modelContext.insert(person)
        dismiss()
    }
}

#Preview {
    AddPersonView()
        .modelContainer(for: Person.self, inMemory: true)
}
