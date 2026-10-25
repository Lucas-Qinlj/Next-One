import Foundation
import CoreGraphics
public struct FloatingGeometry {
    public var anchor: CGPoint
    public var size: CGSize
    public var growsRight: Bool
    public var growsDown: Bool
    public init(anchor: CGPoint, size: CGSize, growsRight: Bool = false, growsDown: Bool = true) {
        self.anchor = anchor; self.size = size; self.growsRight = growsRight; self.growsDown = growsDown
    }
    public var frame: CGRect { CGRect(x: growsRight ? anchor.x : anchor.x - size.width, y: growsDown ? anchor.y - size.height : anchor.y, width: size.width, height: size.height) }
    public mutating func fit(in screen: CGRect, chooseDirection: Bool) {
        size.width = min(max(size.width, 340), screen.width - 48)
        size.height = min(max(size.height, 300), screen.height - 48)
        anchor.x = min(max(anchor.x, screen.minX + 24), screen.maxX - 24)
        anchor.y = min(max(anchor.y, screen.minY + 24), screen.maxY - 24)
        if chooseDirection {
            growsRight = screen.maxX - anchor.x >= size.width || anchor.x - screen.minX < size.width
            growsDown = anchor.y - screen.minY >= size.height || screen.maxY - anchor.y < size.height
        }
        anchor.x = min(max(anchor.x, screen.minX + (growsRight ? 24 : size.width)), screen.maxX - (growsRight ? size.width : 24))
        anchor.y = min(max(anchor.y, screen.minY + (growsDown ? size.height : 24)), screen.maxY - (growsDown ? 24 : size.height))
    }
}
