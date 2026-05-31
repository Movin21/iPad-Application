// Views/Incident/BodyMapView.swift
// NurseryConnect
// PencilKit body map with an inline SwiftUI tool-bar.
//
// PKToolPicker is intentionally NOT used: it requires the canvas to already
// be attached to a UIWindowScene, which is unreliable inside a modal sheet on
// iPadOS. Instead we set canvas.tool directly from a SwiftUI control, which
// is always reliable regardless of presentation context.

import SwiftUI
import PencilKit

// MARK: - BodyMapView

struct BodyMapView: View {
    @Binding var frontDrawingData: Data
    @Binding var backDrawingData:  Data

    @State private var showFront   = true
    @State private var activeTool: DrawTool = .pen

    // MARK: - Tool enum

    enum DrawTool: String, CaseIterable, Equatable {
        case pen    = "Pen"
        case marker = "Marker"
        case eraser = "Eraser"

        var symbol: String {
            switch self {
            case .pen:    return "pencil"
            case .marker: return "highlighter"
            case .eraser: return "eraser.fill"
            }
        }

        var pkTool: PKTool {
            switch self {
            case .pen:
                // Clinical red ink — injury marking convention
                return PKInkingTool(.pen,    color: .systemRed,                       width: 3)
            case .marker:
                // Semi-transparent highlight for broad areas
                return PKInkingTool(.marker, color: UIColor.systemRed.withAlphaComponent(0.45), width: 18)
            case .eraser:
                return PKEraserTool(.bitmap, width: 22)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 14) {

            // Front / Back toggle
            Picker("Body view", selection: $showFront.animation(.spring(response: 0.32))) {
                Text("Front").tag(true)
                Text("Back").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)

            // Body outline + PencilKit canvas
            // .id(showFront) forces makeUIView when the side changes so the
            // canvas loads the correct drawing rather than reusing the old one.
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.white)

                Image(showFront ? "BodyMapFront" : "BodyMapBack")
                    .resizable()
                    .scaledToFit()
                    .padding(20)

                Group {
                    if showFront {
                        PKCanvasRepresentable(
                            drawingData: $frontDrawingData,
                            activeTool:  activeTool
                        )
                    } else {
                        PKCanvasRepresentable(
                            drawingData: $backDrawingData,
                            activeTool:  activeTool
                        )
                    }
                }
                .id(showFront)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .aspectRatio(0.42, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .ncCardShadow()
            .padding(.horizontal, 8)

            // Inline tool-bar: tool selector + clear button
            toolBar
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Tool bar

    private var toolBar: some View {
        HStack(spacing: 8) {
            ForEach(DrawTool.allCases, id: \.self) { tool in
                Button {
                    activeTool = tool
                    HapticFeedback.light()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tool.symbol)
                            .font(.subheadline.weight(.semibold))
                        Text(tool.rawValue)
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(activeTool == tool ? Color.ncAccent : Color.ncOnSurfaceVariant)
                    .frame(minWidth: 52)
                    .padding(.vertical, 8)
                    .background(
                        activeTool == tool
                            ? Color.ncAccent.opacity(0.12)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: NCRadius.badge)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Undo
            Button {
                NotificationCenter.default.post(name: .bodyMapUndo, object: showFront)
                HapticFeedback.light()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.ncOnSurfaceVariant)
            }
            .buttonStyle(.plain)

            // Clear current view
            Button(role: .destructive) {
                if showFront { frontDrawingData = Data() }
                else         { backDrawingData  = Data() }
                HapticFeedback.medium()
            } label: {
                Label("Clear", systemImage: "trash")
                    .font(.caption.weight(.medium))
            }
            .disabled(showFront ? frontDrawingData.isEmpty : backDrawingData.isEmpty)
        }
    }
}

// MARK: - PKCanvasView UIViewRepresentable

private struct PKCanvasRepresentable: UIViewRepresentable {
    @Binding var drawingData: Data
    let activeTool: BodyMapView.DrawTool

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput   // Apple Pencil and finger
        canvas.backgroundColor = .clear
        canvas.isOpaque        = false
        canvas.tool            = activeTool.pkTool
        canvas.delegate        = context.coordinator
        context.coordinator.currentTool = activeTool

        // Restore existing drawing, if any
        if !drawingData.isEmpty, let saved = try? PKDrawing(data: drawingData) {
            canvas.drawing = saved
        }

        // Register for undo notifications (posted by the toolbar's undo button)
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleUndo(_:)),
            name: .bodyMapUndo,
            object: nil
        )

        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Switch tool only when the selection changed, not on every redraw.
        // This avoids interrupting an in-progress stroke.
        if context.coordinator.currentTool != activeTool {
            context.coordinator.currentTool = activeTool
            canvas.tool = activeTool.pkTool
        }

        // Sync drawing when the binding was reset externally (clear button).
        let target: PKDrawing
        if drawingData.isEmpty {
            target = PKDrawing()
        } else if let d = try? PKDrawing(data: drawingData) {
            target = d
        } else { return }

        if canvas.drawing.dataRepresentation() != target.dataRepresentation() {
            canvas.drawing = target
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(drawingData: $drawingData) }

    // MARK: Coordinator

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawingData: Data
        var currentTool: BodyMapView.DrawTool = .pen
        weak var canvas: PKCanvasView?

        init(drawingData: Binding<Data>) { _drawingData = drawingData }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            canvas = canvasView
            drawingData = canvasView.drawing.dataRepresentation()
        }

        @objc func handleUndo(_ note: Notification) {
            // The notification's object encodes which side is active (Bool).
            // We undo regardless of side to keep it simple — the canvas that
            // is currently live will receive the undo.
            canvas?.undoManager?.undo()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// MARK: - Notification name

private extension Notification.Name {
    static let bodyMapUndo = Notification.Name("NurseryConnect.BodyMapUndo")
}

// MARK: - Preview

#Preview {
    @Previewable @State var front = Data()
    @Previewable @State var back  = Data()
    return NavigationStack {
        ScrollView {
            BodyMapView(frontDrawingData: $front, backDrawingData: $back)
                .padding()
        }
        .navigationTitle("Body Map Preview")
    }
}
