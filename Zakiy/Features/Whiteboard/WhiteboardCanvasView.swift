import SwiftUI

/// A shared drawing surface synced over the room socket. Strokes from every participant are
/// rendered from `socket.roomState.boardStrokes`; only participants with `canManageContent`
/// (the host or a granted co-host) can draw or clear the board.
struct WhiteboardCanvasView: View {
    @Bindable var socket: RoomSocketManager

    @State private var currentPoints: [[Double]] = []
    @State private var selectedColor: Color = .black
    @State private var lineWidth: Double = 4

    private var canDraw: Bool { socket.roomState.isHost || socket.roomState.canManageContent }

    private let palette: [Color] = [.black, .red, .blue, .green, .orange]

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack {
                    Color.white

                    Canvas { context, _ in
                        for stroke in socket.roomState.boardStrokes {
                            draw(stroke, in: &context)
                        }
                        if !currentPoints.isEmpty {
                            var livePath = Path()
                            livePath.addLines(currentPoints.map { CGPoint(x: $0[0], y: $0[1]) })
                            context.stroke(livePath, with: .color(selectedColor), lineWidth: lineWidth)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    canDraw ?
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            currentPoints.append([value.location.x, value.location.y])
                        }
                        .onEnded { _ in
                            guard currentPoints.count > 1 else { currentPoints = []; return }
                            socket.sendBoardStroke(BoardStroke(
                                mode: "pen",
                                points: currentPoints,
                                color: selectedColor.hexString,
                                width: lineWidth
                            ))
                            currentPoints = []
                        }
                    : nil
                )
            }

            if canDraw {
                toolbar
            }
        }
        .background(Color.appBackground)
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            ForEach(palette, id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color.primary.opacity(selectedColor == color ? 0.6 : 0), lineWidth: 2))
                    .onTapGesture { selectedColor = color }
            }
            Spacer()
            Button(role: .destructive) {
                socket.clearBoard()
            } label: {
                Image(systemName: "trash")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.appCard)
    }

    private func draw(_ stroke: BoardStroke, in context: inout GraphicsContext) {
        guard let points = stroke.points, points.count > 1 else { return }
        var path = Path()
        path.addLines(points.map { CGPoint(x: $0[0], y: $0[1]) })
        context.stroke(path, with: .color(Color(hex: stroke.color)), lineWidth: stroke.width ?? 4)
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
