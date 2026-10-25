import AppKit

enum ResizeCursor {
    static func cursor(horizontal: Bool, vertical: Bool, growsRight: Bool, growsDown: Bool) -> NSCursor {
        if #available(macOS 15.0, *) {
            let position: NSCursor.FrameResizePosition
            if horizontal && vertical {
                position = growsRight ? (growsDown ? .bottomRight : .topRight) : (growsDown ? .bottomLeft : .topLeft)
            } else if horizontal { position = growsRight ? .right : .left }
            else { position = growsDown ? .bottom : .top }
            return .frameResize(position: position, directions: .all)
        }
        if horizontal && vertical { return growsRight == growsDown ? diagonalDown : diagonalUp }
        return horizontal ? .resizeLeftRight : .resizeUpDown
    }

    // macOS 14 has no public diagonal resize cursor; keep both arrowheads visible on any background.
    private static let diagonalDown = diagonal(descending: true)
    private static let diagonalUp = diagonal(descending: false)

    static func diagonal(descending: Bool) -> NSCursor {
        let image = NSImage(size: NSSize(width: 32, height: 32), flipped: false) { _ in
            let start = NSPoint(x: 7, y: descending ? 25 : 7)
            let end = NSPoint(x: 25, y: descending ? 7 : 25)
            let direction: CGFloat = descending ? -1 : 1
            let path = NSBezierPath()
            path.move(to: start); path.line(to: end)
            path.move(to: NSPoint(x: 14, y: start.y)); path.line(to: start)
            path.line(to: NSPoint(x: start.x, y: start.y + 7 * direction))
            path.move(to: NSPoint(x: 18, y: end.y)); path.line(to: end)
            path.line(to: NSPoint(x: end.x, y: end.y - 7 * direction))
            path.lineCapStyle = .round; path.lineJoinStyle = .round
            NSColor.white.setStroke(); path.lineWidth = 4; path.stroke()
            NSColor.black.setStroke(); path.lineWidth = 2; path.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 16, y: 16))
    }
}
