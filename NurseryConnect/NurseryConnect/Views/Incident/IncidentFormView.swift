// Views/Incident/IncidentFormView.swift
// NurseryConnect
// RIDDOR-aligned incident report form with PencilKit body map annotation.
// Implements Manager countersignature workflow state.

import SwiftUI
import SwiftData

struct IncidentFormView: View {
    let child: Child
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    @State private var incidentType: IncidentType = .accident
    @State private var title          = ""
    @State private var description    = ""
    @State private var location       = ""
    @State private var witnesses      = ""

    // PencilKit body map — separate Data payloads for front and back views
    @State private var frontDrawingData = Data()
    @State private var backDrawingData  = Data()

    @State private var riddorRequired  = false
    @State private var parentNotified  = false
    @State private var parentSig       = ""

    @State private var showBodyMap     = false
    @State private var showSuccess     = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasBodyMapAnnotation: Bool {
        !frontDrawingData.isEmpty || !backDrawingData.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Incident Details
                Section("Incident Details") {
                    Picker("Type", selection: $incidentType) {
                        ForEach(IncidentType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }

                    if incidentType.isRiddorRelevant {
                        Label(
                            "This incident type may require RIDDOR reporting to the HSE.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(Color.ncWarning)
                        .listRowBackground(Color.ncWarning.opacity(0.08))
                    }

                    TextField("Incident Title (required)", text: $title)
                    TextField("Location in setting", text: $location)
                }

                // MARK: Description
                Section("Description") {
                    TextField(
                        "Describe exactly what happened, in chronological order…",
                        text: $description,
                        axis: .vertical
                    )
                    .lineLimit(5...12)
                }

                // MARK: Body Map (PencilKit)
                Section {
                    if hasBodyMapAnnotation {
                        HStack {
                            Label("Body map annotated", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Color.ncSuccess)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Button("Edit") {
                                HapticFeedback.light()
                                showBodyMap = true
                            }
                            .foregroundStyle(Color.ncAccent)
                            .font(.subheadline.weight(.medium))
                        }
                    } else {
                        Button {
                            HapticFeedback.medium()
                            showBodyMap = true
                        } label: {
                            Label("Annotate Body Map", systemImage: "pencil.and.outline")
                                .foregroundStyle(Color.ncAccent)
                        }
                    }
                } header: {
                    Text("Body Map")
                } footer: {
                    Text("Draw directly with Apple Pencil or finger to mark injury locations on the body outline.")
                }

                // MARK: Witnesses
                Section("Witnesses") {
                    TextField("Witness names (comma separated)", text: $witnesses, axis: .vertical)
                        .lineLimit(2...4)
                }

                // MARK: RIDDOR
                if incidentType.isRiddorRelevant {
                    Section("RIDDOR") {
                        Toggle("RIDDOR Reportable to HSE", isOn: $riddorRequired)
                    }
                }

                // MARK: Parent Notification
                Section("Parent Notification") {
                    Toggle("Parent / Carer Notified", isOn: $parentNotified.animation())
                    if parentNotified {
                        TextField("Parent/Carer printed name (acknowledgement)", text: $parentSig)
                            .transition(.opacity)
                    }
                }

                // MARK: Compliance Note
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundStyle(Color.ncWarning)
                        Text("This incident will be submitted as **Pending Review** and requires a Manager countersignature before it is considered complete.")
                            .font(.subheadline)
                    }
                    .listRowBackground(Color.ncWarning.opacity(0.08))
                } header: {
                    Text("Compliance Note")
                }
            }
            .navigationTitle("Incident Report")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.ncAccent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { save() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                        .foregroundStyle(isValid ? Color.ncAlert : .secondary)
                }
            }
            // Body map sheet — BodyMapView fills full sheet height; no outer ScrollView
            // (the inner BodyScrollView handles pan/zoom; nesting inside ScrollView breaks it)
            .sheet(isPresented: $showBodyMap) {
                NavigationStack {
                    BodyMapView(
                        frontDrawingData: $frontDrawingData,
                        backDrawingData:  $backDrawingData
                    )
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                    .navigationTitle("Body Map — \(child.firstName)")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                HapticFeedback.success()
                                showBodyMap = false
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
            .overlay(successOverlay)
        }
    }

    // MARK: - Success Overlay

    @ViewBuilder
    private var successOverlay: some View {
        if showSuccess {
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.ncSuccess)
                    Text("Incident Submitted — Pending Review")
                        .fontWeight(.semibold)
                }
                .padding()
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Save

    private func save() {
        let incident = Incident(
            keyworkerName:  kKeyworkerName,
            incidentType:   incidentType,
            title:          title.trimmingCharacters(in: .whitespaces),
            descriptionText: description.trimmingCharacters(in: .whitespaces),
            location:       location,
            riddorRequired: riddorRequired && incidentType.isRiddorRelevant,
            witnessNames:   witnesses
        )

        // Store PencilKit drawing data (nil if no annotation made)
        incident.pencilDrawingFrontData = frontDrawingData.isEmpty ? nil : frontDrawingData
        incident.pencilDrawingBackData  = backDrawingData.isEmpty  ? nil : backDrawingData

        incident.parentNotified   = parentNotified
        incident.parentNotifiedAt = parentNotified ? Date() : nil
        incident.parentSignature  = parentSig
        incident.reviewStatus     = .pendingReview
        incident.child            = child
        child.incidents.append(incident)
        context.insert(incident)
        try? context.save()

        HapticFeedback.success()
        withAnimation { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { dismiss() }
    }
}
