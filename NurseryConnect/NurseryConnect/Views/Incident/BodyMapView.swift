// Views/Incident/BodyMapView.swift
// NurseryConnect
// Interactive body map — uses BodyMapFront asset image with tap-to-mark injury locations.

import SwiftUI

struct BodyMapView: View {
    @Binding var markers: [BodyMapMarker]
    @State private var showFront = true
    @State private var pendingLabel = ""
    @State private var showLabelEntry = false
    @State private var pendingPosition: CGPoint = .zero

    private var currentMarkers: [BodyMapMarker] {
        markers.filter { $0.isFront == showFront }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Front / Back toggle
            Picker("View", selection: $showFront.animation(.spring(response: 0.3))) {
                Text("Front").tag(true)
                Text("Back").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 4)

            // Body image + tap-to-mark overlay
            GeometryReader { geo in
                let size = geo.size
                ZStack(alignment: .topLeading) {
                    // Real body images — front and back assets
                    Image(showFront ? "BodyMapFront" : "BodyMapBack")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width, height: size.height)

                    // Injury markers
                    ForEach(currentMarkers) { marker in
                        markerPin(marker: marker, size: size)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    HapticFeedback.medium()
                    pendingPosition = CGPoint(
                        x: location.x / size.width,
                        y: location.y / size.height
                    )
                    showLabelEntry = true
                }
            }
            .aspectRatio(0.42, contentMode: .fit)
            .padding(.horizontal, 24)

            // Marker legend
            if !currentMarkers.isEmpty {
                markerLegend
            }

            // Help text
            Text("Tap on the body diagram to mark an injury location")
                .font(.caption)
                .foregroundStyle(Color.ncOnSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .alert("Describe the injury", isPresented: $showLabelEntry) {
            TextField("e.g. bruise, graze, redness", text: $pendingLabel)
            Button("Add Marker") {
                let marker = BodyMapMarker(
                    x: pendingPosition.x,
                    y: pendingPosition.y,
                    isFront: showFront,
                    label: pendingLabel.trimmingCharacters(in: .whitespaces)
                )
                markers.append(marker)
                pendingLabel = ""
                HapticFeedback.success()
            }
            Button("Cancel", role: .cancel) { pendingLabel = "" }
        }
    }

    // MARK: - Marker Pin

    private func markerPin(marker: BodyMapMarker, size: CGSize) -> some View {
        let displayX = marker.x * size.width
        let y = marker.y * size.height

        return ZStack {
            Circle()
                .fill(Color.ncAlert.opacity(0.9))
                .frame(width: 22, height: 22)
                .shadow(color: Color.ncAlert.opacity(0.5), radius: 5)
            Circle()
                .fill(.white)
                .frame(width: 9, height: 9)
        }
        .position(x: displayX, y: y)
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                markers.removeAll { $0.id == marker.id }
            }
            HapticFeedback.medium()
        }
    }

    // MARK: - Marker Legend

    private var markerLegend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(showFront ? "Front" : "Back") — \(currentMarkers.count) marker\(currentMarkers.count == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.ncOnSurfaceVariant)
            ForEach(Array(currentMarkers.enumerated()), id: \.offset) { i, marker in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.ncAlert)
                        .frame(width: 8, height: 8)
                    Text("\(i + 1). \(marker.label.isEmpty ? "Unlabelled area" : marker.label)")
                        .font(.caption)
                        .foregroundStyle(Color.ncOnSurface)
                    Spacer()
                    Button {
                        withAnimation { markers.removeAll { $0.id == marker.id } }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.ncOnSurfaceVariant)
                            .font(.caption)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.ncCardBg, in: RoundedRectangle(cornerRadius: NCRadius.badge))
        .padding(.horizontal, 4)
    }
}

#Preview {
    @Previewable @State var markers: [BodyMapMarker] = []
    return BodyMapView(markers: $markers)
        .padding()
}
