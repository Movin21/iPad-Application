// Views/Incident/BodyMapView.swift
// NurseryConnect
// PencilKit body map with pinch-to-zoom, +/- zoom buttons, Draw/Mark/Eraser tools.
//
// Architecture:
//   BodyScrollView (UIScrollView subclass — fires onLayout in layoutSubviews)
//     └── containerView (UIView — viewForZooming target)
//           ├── UIImageView  (body silhouette)
//           └── PKCanvasView (transparent drawing layer, own scroll disabled)
//
// PKToolPicker is NOT used — it requires a fully-attached UIWindowScene which is
// unreliable inside a modal sheet. canvas.tool is set directly from SwiftUI state.

import SwiftUI
import PencilKit

// MARK: - Zoom proxy  (connects SwiftUI buttons → UIScrollView methods)

final class BodyMapZoomProxy {
    var zoomIn:    (() -> Void)?
    var zoomOut:   (() -> Void)?
    var resetZoom: (() -> Void)?
}

// MARK: - UIScrollView subclass that fires a layout callback

private final class BodyScrollView: UIScrollView {
    var onLayout: ((CGSize) -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?(bounds.size)
    }
}

// MARK: - BodyMapView

struct BodyMapView: View {
    @Binding var frontDrawingData: Data
    @Binding var backDrawingData:  Data

    @State private var showFront   = true
    @State private var activeTool: DrawTool = .pen
    // Separate proxies so the correct scroll view is targeted after .id() recreation
    @State private var frontProxy  = BodyMapZoomProxy()
    @State private var backProxy   = BodyMapZoomProxy()

    private var activeProxy: BodyMapZoomProxy { showFront ? frontProxy : backProxy }

    // MARK: DrawTool

    enum DrawTool: String, CaseIterable, Equatable {
        case pen    = "Draw"
        case marker = "Mark"
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
                return PKInkingTool(.pen,    color: .systemRed, width: 3)
            case .marker:
                return PKInkingTool(.marker, color: UIColor.systemRed.withAlphaComponent(0.45), width: 18)
            case .eraser:
                return PKEraserTool(.bitmap, width: 22)
            }
        }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 12) {

            // Front / Back toggle
            Picker("Body view", selection: $showFront.animation(.spring(response: 0.32))) {
                Text("Front").tag(true)
                Text("Back").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)

            // Canvas — fills all remaining vertical space
            ZStack(alignment: .topTrailing) {
                canvasLayer
                zoomControls.padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
            .padding(.horizontal, 8)

            // Bottom tool bar
            toolBar
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
        }
    }

    // MARK: Canvas layer

    @ViewBuilder
    private var canvasLayer: some View {
        Group {
            if showFront {
                BodyCanvasRepresentable(
                    drawingData: $frontDrawingData,
                    imageName:   "BodyMapFront",
                    activeTool:  activeTool,
                    proxy:       frontProxy
                )
            } else {
                BodyCanvasRepresentable(
                    drawingData: $backDrawingData,
                    imageName:   "BodyMapBack",
                    activeTool:  activeTool,
                    proxy:       backProxy
                )
            }
        }
        .id(showFront)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Zoom controls overlay

    private var zoomControls: some View {
        VStack(spacing: 6) {
            zoomButton(symbol: "plus.magnifyingglass")                      { activeProxy.zoomIn?() }
            zoomButton(symbol: "minus.magnifyingglass")                     { activeProxy.zoomOut?() }
            zoomButton(symbol: "arrow.down.right.and.arrow.up.left")        { activeProxy.resetZoom?() }
        }
    }

    private func zoomButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticFeedback.light()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.ncAccent)
                .frame(width: 38, height: 38)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    // MARK: Tool bar

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
                    .frame(minWidth: 56)
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

            // Clear current side
            Button(role: .destructive) {
                if showFront { frontDrawingData = Data() }
                else         { backDrawingData  = Data() }
                activeProxy.resetZoom?()
                HapticFeedback.medium()
            } label: {
                Label("Clear", systemImage: "trash")
                    .font(.caption.weight(.medium))
            }
            .disabled(showFront ? frontDrawingData.isEmpty : backDrawingData.isEmpty)
        }
    }
}

// MARK: - BodyCanvasRepresentable

private struct BodyCanvasRepresentable: UIViewRepresentable {
    @Binding var drawingData: Data
    let imageName:  String
    let activeTool: BodyMapView.DrawTool
    let proxy:      BodyMapZoomProxy

    // MARK: makeUIView

    func makeUIView(context: Context) -> BodyScrollView {
        let coordinator = context.coordinator

        let scrollView = BodyScrollView()
        scrollView.backgroundColor                = .white
        scrollView.delegate                       = coordinator
        scrollView.minimumZoomScale               = 0.3
        scrollView.maximumZoomScale               = 5.0
        scrollView.bouncesZoom                    = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator   = false

        // Container — the single view returned by viewForZooming
        let container = UIView()
        container.backgroundColor = .clear
        scrollView.addSubview(container)

        // Body silhouette image
        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode     = .scaleAspectFit
        imageView.backgroundColor = .clear
        container.addSubview(imageView)

        // PencilKit canvas — its own UIScrollView scroll disabled; outer handles it
        let canvas = PKCanvasView()
        canvas.drawingPolicy   = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque        = false
        canvas.isScrollEnabled = false
        canvas.tool            = activeTool.pkTool
        canvas.delegate        = coordinator
        container.addSubview(canvas)

        coordinator.scrollView  = scrollView
        coordinator.container   = container
        coordinator.canvas      = canvas
        coordinator.imageView   = imageView
        coordinator.currentTool = activeTool

        // Restore saved drawing
        if !drawingData.isEmpty, let saved = try? PKDrawing(data: drawingData) {
            canvas.drawing = saved
        }

        // Undo notifications
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(Coordinator.handleUndo(_:)),
            name: .bodyMapUndo,
            object: nil
        )

        // Layout callback — fires every time bounds change (first appear, rotation, etc.)
        scrollView.onLayout = { [weak coordinator] size in
            coordinator?.updateLayout(boundsSize: size)
        }

        // Proxy zoom callbacks
        proxy.zoomIn = { [weak scrollView] in
            guard let sv = scrollView else { return }
            sv.setZoomScale(min(sv.zoomScale * 1.5, sv.maximumZoomScale), animated: true)
        }
        proxy.zoomOut = { [weak scrollView] in
            guard let sv = scrollView else { return }
            sv.setZoomScale(max(sv.zoomScale / 1.5, sv.minimumZoomScale), animated: true)
        }
        proxy.resetZoom = { [weak scrollView] in
            guard let sv = scrollView else { return }
            sv.setZoomScale(sv.minimumZoomScale, animated: true)
        }

        return scrollView
    }

    // MARK: updateUIView

    func updateUIView(_ scrollView: BodyScrollView, context: Context) {
        let coord = context.coordinator

        // Tool switch guard — avoids interrupting an in-progress stroke
        if coord.currentTool != activeTool {
            coord.currentTool  = activeTool
            coord.canvas?.tool = activeTool.pkTool
        }

        // Sync drawing when binding was reset externally (Clear button)
        guard let canvas = coord.canvas else { return }
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

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIScrollViewDelegate {
        @Binding var drawingData: Data
        var currentTool: BodyMapView.DrawTool = .pen
        weak var scrollView: BodyScrollView?
        weak var container:  UIView?
        weak var canvas:     PKCanvasView?
        weak var imageView:  UIImageView?
        private var lastLayoutSize: CGSize = .zero

        init(drawingData: Binding<Data>) { _drawingData = drawingData }

        // Called from BodyScrollView.onLayout — sets up content size and fit zoom.
        func updateLayout(boundsSize size: CGSize) {
            guard size.width > 0, size != lastLayoutSize,
                  let scrollView = scrollView,
                  let container  = container,
                  let imageView  = imageView,
                  let canvas     = canvas
            else { return }
            lastLayoutSize = size

            // Canonical canvas size — full bounds width × image aspect ratio
            let image    = imageView.image ?? UIImage()
            let aspect   = image.size.width > 0
                ? image.size.height / image.size.width
                : 2.38
            let content  = CGSize(width: size.width, height: size.width * aspect)

            container.frame        = CGRect(origin: .zero, size: content)
            imageView.frame        = container.bounds
            canvas.frame           = container.bounds
            scrollView.contentSize = content

            // Fit scale: smallest scale that shows the complete body
            let fitScale = min(size.width / content.width,
                               size.height / content.height)
            let minScale = max(fitScale, 0.3)
            scrollView.minimumZoomScale = minScale
            scrollView.maximumZoomScale = minScale * 5

            // Apply fit zoom on first layout only
            if scrollView.zoomScale >= 1.0 {
                scrollView.setZoomScale(minScale, animated: false)
            }
        }

        // UIScrollViewDelegate — which view to zoom
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { container }

        // Re-centre content when smaller than the scroll view (standard pattern)
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let container = container else { return }
            let offsetX = max((scrollView.bounds.width  - scrollView.contentSize.width)  / 2, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
            container.center = CGPoint(
                x: scrollView.contentSize.width  / 2 + offsetX,
                y: scrollView.contentSize.height / 2 + offsetY
            )
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawingData = canvasView.drawing.dataRepresentation()
        }

        @objc func handleUndo(_ note: Notification) {
            canvas?.undoManager?.undo()
        }

        deinit { NotificationCenter.default.removeObserver(self) }
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
        BodyMapView(frontDrawingData: $front, backDrawingData: $back)
            .padding(.horizontal, 8)
    }
}
