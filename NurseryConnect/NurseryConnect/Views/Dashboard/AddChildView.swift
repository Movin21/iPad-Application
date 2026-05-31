// Views/Dashboard/AddChildView.swift
// NurseryConnect
// Form to register a new child in the keyworker's group.

import SwiftUI
import SwiftData

struct AddChildView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var firstName    = ""
    @State private var lastName     = ""
    @State private var dob          = Date()
    @State private var allergyInput = ""
    @State private var allergies: [String] = []
    @State private var medicalNotes = ""
    @State private var dietaryReqs  = ""
    @State private var contactName  = ""
    @State private var contactPhone = ""

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Child Details") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name",  text: $lastName)
                    DatePicker("Date of Birth", selection: $dob,
                               in: ...Date(),
                               displayedComponents: .date)
                }

                Section {
                    HStack {
                        TextField("Add allergen (e.g. Nuts)", text: $allergyInput)
                        Button {
                            let val = allergyInput.trimmingCharacters(in: .whitespaces)
                            guard !val.isEmpty else { return }
                            allergies.append(val)
                            allergyInput = ""
                            HapticFeedback.light()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.ncAlert)
                        }
                    }
                    ForEach(allergies, id: \.self) { a in
                        Label(a, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.ncAlert)
                    }
                    .onDelete { idx in allergies.remove(atOffsets: idx) }
                } header: {
                    Text("Allergens")
                } footer: {
                    Text("These will appear as high-visibility alerts throughout the app.")
                }

                Section("Medical Notes") {
                    TextField("EpiPen, inhaler, conditions…", text: $medicalNotes, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Dietary requirements", text: $dietaryReqs, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Emergency Contact") {
                    TextField("Parent / Guardian Name", text: $contactName)
                    TextField("Phone Number", text: $contactPhone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("New Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                        .foregroundStyle(isValid ? Color.ncAccent : Color.ncOnSurfaceVariant)
                }
            }
        }
        .tint(Color.ncAccent)
    }

    private func save() {
        let child = Child(
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName:  lastName.trimmingCharacters(in: .whitespaces),
            dateOfBirth: dob,
            assignedKeyworkerName: kKeyworkerName,
            allergies: allergies,
            medicalNotes: medicalNotes,
            dietaryRequirements: dietaryReqs,
            emergencyContactName: contactName,
            emergencyContactPhone: contactPhone
        )
        let milestones = EYFSMilestoneCatalogue.defaults(keyworkerName: kKeyworkerName)
        milestones.forEach { $0.child = child }
        child.milestones = milestones

        context.insert(child)
        try? context.save()
        HapticFeedback.success()
        dismiss()
    }
}
