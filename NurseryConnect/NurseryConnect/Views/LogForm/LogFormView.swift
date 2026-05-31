// Views/LogForm/LogFormView.swift
// NurseryConnect
// Daily observation form — EYFS area, sleep, nappy, mood/wellbeing.
// Auto-timestamps and attributes entry to the current keyworker.

import SwiftUI
import SwiftData

struct LogFormView: View {
    let child: Child
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // EYFS
    @State private var eyfsArea: EYFSArea = .communication
    @State private var activityDescription = ""
    @State private var learningNotes = ""

    // Mood
    @State private var mood: MoodLevel = .happy
    @State private var wellbeingNotes = ""

    // Sleep
    @State private var hasSleep = false
    @State private var sleepStart = Date()
    @State private var sleepEnd   = Date()

    // Nappy
    @State private var hasNappy = false
    @State private var nappyType: NappyType = .wet
    @State private var nappyNotes = ""

    @State private var showSuccess = false

    private var isValid: Bool {
        !activityDescription.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Allergen reminder at top of form
                if child.hasActiveAlerts {
                    Section {
                        AlertBannerView(child: child)
                            .listRowInsets(.init())
                            .listRowBackground(Color.clear)
                    }
                }

                // MARK: EYFS Observation
                Section("EYFS Observation") {
                    Picker("Area of Learning", selection: $eyfsArea) {
                        ForEach(EYFSArea.allCases, id: \.self) { area in
                            Label(area.rawValue, systemImage: area.sfSymbol).tag(area)
                        }
                    }
                    TextField("Activity / Observation (required)", text: $activityDescription, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Learning notes…", text: $learningNotes, axis: .vertical)
                        .lineLimit(2...4)
                }

                // MARK: Mood & Wellbeing
                Section("Mood & Wellbeing") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How is \(child.firstName) feeling?")
                            .font(.subheadline)
                            .foregroundStyle(Color.ncOnSurfaceVariant)
                        moodPicker
                    }
                    .padding(.vertical, 4)

                    TextField("Wellbeing notes…", text: $wellbeingNotes, axis: .vertical)
                        .lineLimit(2...4)
                }

                // MARK: Sleep Record
                Section {
                    Toggle("Record Sleep", isOn: $hasSleep.animation())
                    if hasSleep {
                        DatePicker("Sleep Start", selection: $sleepStart, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("Sleep End",   selection: $sleepEnd,   displayedComponents: [.date, .hourAndMinute])

                        let dur = max(0, Int(sleepEnd.timeIntervalSince(sleepStart) / 60))
                        Label("\(dur / 60)h \(dur % 60)m sleep", systemImage: "moon.zzz.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.ncAccent)
                    }
                } header: {
                    Text("Sleep")
                }

                // MARK: Nappy / Toileting
                Section {
                    Toggle("Record Nappy / Toileting", isOn: $hasNappy.animation())
                    if hasNappy {
                        Picker("Type", selection: $nappyType) {
                            ForEach(NappyType.allCases, id: \.self) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                        TextField("Notes…", text: $nappyNotes)
                    }
                } header: {
                    Text("Nappy / Toileting")
                }
            }
            .navigationTitle("Log Observation")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.ncAccent)
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
            .overlay(successOverlay)
        }
    }

    // MARK: - Mood Picker

    private var moodPicker: some View {
        HStack(spacing: 0) {
            ForEach(MoodLevel.allCases, id: \.self) { level in
                Button {
                    withAnimation(.spring(response: 0.3)) { mood = level }
                    HapticFeedback.light()
                } label: {
                    VStack(spacing: 4) {
                        MoodIconView(mood: level, size: mood == level ? 42 : 34)
                            .scaleEffect(mood == level ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3), value: mood)
                        Text(level.rawValue)
                            .font(.caption2)
                            .foregroundStyle(mood == level ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        mood == level
                        ? Color.ncAccent.opacity(0.15)
                        : Color.clear,
                        in: RoundedRectangle(cornerRadius: NCRadius.badge)
                    )
                }
                .buttonStyle(.plain)
            }
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
                    Text("Observation Saved")
                        .fontWeight(.semibold)
                }
                .padding()
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .animation(.spring(response: 0.4), value: showSuccess)
        }
    }

    // MARK: - Save

    private func save() {
        let obs = DailyLog(
            keyworkerName: kKeyworkerName,
            eyfsArea: eyfsArea,
            activityDescription: activityDescription.trimmingCharacters(in: .whitespaces),
            learningNotes: learningNotes.trimmingCharacters(in: .whitespaces),
            hasSleepRecord: hasSleep,
            sleepStart: hasSleep ? sleepStart : nil,
            sleepEnd:   hasSleep ? sleepEnd   : nil,
            hasNappyRecord: hasNappy,
            nappyType: hasNappy ? nappyType : nil,
            nappyNotes: hasNappy ? nappyNotes : "",
            mood: mood,
            wellbeingNotes: wellbeingNotes
        )
        obs.child = child
        child.observations.append(obs)
        context.insert(obs)
        try? context.save()

        HapticFeedback.success()
        withAnimation { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
    }
}
