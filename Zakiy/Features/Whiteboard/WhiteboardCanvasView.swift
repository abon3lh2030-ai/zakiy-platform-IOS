import SwiftUI

private enum WhiteboardTool {
    case pen, eraser, text
}

/// A shared drawing surface synced over the room socket. Strokes from every participant are
/// rendered from `socket.roomState.boardStrokes`; only participants with `canManageContent`
/// (the host or a granted co-host) can draw, place text, or clear the board.
struct WhiteboardCanvasView: View {
    @Bindable var socket: RoomSocketManager

    @State private var currentPoints: [[Double]] = []
    @State private var selectedColor: Color = .black
    @State private var lineWidth: Double = 4
    @State private var tool: WhiteboardTool = .pen
    @State private var pendingTextLocation: CGPoint?
    @State private var newText = ""

    private var canDraw: Bool { socket.roomState.isHost || socket.roomState.canManageContent }

    private let palette: [Color] = [.purple, .orange, .green, .blue, .red, .black]

    private var penStrokes: [BoardStroke] { socket.roomState.boardStrokes.filter { $0.mode != "text" } }
    private var textStrokes: [BoardStroke] { socket.roomState.boardStrokes.filter { $0.mode == "text" } }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack {
                    Color.white

                    Canvas { context, _ in
                        for stroke in penStrokes {
                            draw(stroke, in: &context)
                        }
                        if !currentPoints.isEmpty, tool != .text {
                            var livePath = Path()
                            livePath.addLines(currentPoints.map { CGPoint(x: $0[0], y: $0[1]) })
                            context.stroke(livePath, with: .color(tool == .eraser ? .white : selectedColor), lineWidth: tool == .eraser ? lineWidth * 4 : lineWidth)
                        }
                    }

                    ForEach(textStrokes) { stroke in
                        WhiteboardTextElement(stroke: stroke, canDraw: canDraw) { newX, newY, newFontSize in
                            socket.sendBoardUpdateStroke(id: stroke.id, x: newX, y: newY, fontSize: newFontSize)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(canDraw ? drawGesture : nil)
                .simultaneousGesture(canDraw ? textTapGesture : nil)
            }
            .frame(minHeight: 240)

            if canDraw {
                toolbar
            }
        }
        .background(Color.appBackground)
        .alert(Loc.t("add_text_to_board"), isPresented: Binding(
            get: { pendingTextLocation != nil },
            set: { if !$0 { pendingTextLocation = nil } }
        )) {
            TextField(Loc.t("text_placeholder"), text: $newText)
            Button(Loc.t("cancel"), role: .cancel) { newText = ""; pendingTextLocation = nil }
            Button(Loc.t("add")) { placeText() }
                .disabled(newText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var textTapGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard tool == .text else { return }
                pendingTextLocation = value.location
            }
    }

    private var drawGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard tool != .text else { return }
                currentPoints.append([value.location.x, value.location.y])
            }
            .onEnded { _ in
                guard tool != .text, currentPoints.count > 1 else { currentPoints = []; return }
                socket.sendBoardStroke(BoardStroke(
                    mode: "pen",
                    points: currentPoints,
                    color: tool == .eraser ? "#FFFFFF" : selectedColor.hexString,
                    width: tool == .eraser ? lineWidth * 4 : lineWidth
                ))
                currentPoints = []
            }
    }

    private func placeText() {
        let text = newText.trimmingCharacters(in: .whitespaces)
        guard let location = pendingTextLocation, !text.isEmpty else {
            newText = ""; pendingTextLocation = nil
            return
        }
        socket.sendBoardStroke(BoardStroke(
            mode: "text",
            color: selectedColor.hexString,
            text: text,
            x: location.x,
            y: location.y,
            fontSize: 20
        ))
        newText = ""
        pendingTextLocation = nil
    }

    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                toolButton(.pen, systemImage: "pencil")
                toolButton(.eraser, systemImage: "eraser")
                toolButton(.text, systemImage: "textformat")

                Divider().frame(height: 26)

                ForEach(palette, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Color.primary.opacity(selectedColor == color ? 0.6 : 0), lineWidth: 2.5))
                        .onTapGesture { selectedColor = color }
                }

                Divider().frame(height: 26)

                Button(role: .destructive) {
                    socket.clearBoard()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                        .frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
        }
        .background(Color.appCard)
    }

    private func toolButton(_ candidate: WhiteboardTool, systemImage: String) -> some View {
        Button {
            tool = candidate
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundStyle(tool == candidate ? Color.appAccentText : .primary)
                .frame(width: 36, height: 36)
                .background(tool == candidate ? Color.accentColor : Color.clear, in: Circle())
        }
    }

    private func draw(_ stroke: BoardStroke, in context: inout GraphicsContext) {
        guard let points = stroke.points, points.count > 1 else { return }
        var path = Path()
        path.addLines(points.map { CGPoint(x: $0[0], y: $0[1]) })
        context.stroke(path, with: .color(Color(hex: stroke.color)), lineWidth: stroke.width ?? 4)
    }
}

/// A single draggable, pinch-resizable text element placed on the board — moving or resizing it
/// patches the existing stroke in place (`board_update_stroke`) instead of creating a new one.
private struct WhiteboardTextElement: View {
    let stroke: BoardStroke
    let canDraw: Bool
    let onCommit: (Double, Double, Double) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var pinchScale: CGFloat = 1

    private var basePosition: CGPoint {
        CGPoint(x: stroke.x ?? 0, y: stroke.y ?? 0)
    }

    private var baseFontSize: Double { stroke.fontSize ?? 20 }

    var body: some View {
        Text(stroke.text ?? "")
            .font(.system(size: baseFontSize * pinchScale))
            .foregroundStyle(Color(hex: stroke.color))
            .position(x: basePosition.x + dragOffset.width, y: basePosition.y + dragOffset.height)
            .gesture(canDraw ? combinedGesture : nil)
    }

    private var combinedGesture: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { value in dragOffset = value.translation }
                .onEnded { value in
                    let newX = basePosition.x + value.translation.width
                    let newY = basePosition.y + value.translation.height
                    dragOffset = .zero
                    onCommit(newX, newY, baseFontSize)
                },
            MagnificationGesture()
                .onChanged { value in pinchScale = value }
                .onEnded { value in
                    let newFontSize = max(10, baseFontSize * value)
                    pinchScale = 1
                    onCommit(basePosition.x, basePosition.y, newFontSize)
                }
        )
    }
}

private extension Color {
    var hexString: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
