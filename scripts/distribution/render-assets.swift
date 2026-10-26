// Regenerate the app icon and installer background using macOS drawing APIs.
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: 1)
}
func render(_ name: String, width: Int, height: Int, scale: Int = 1, draw: () -> Void) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * scale,
        pixelsHigh: height * scale, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}
func stroke(_ points: [NSPoint], width: CGFloat, ink: NSColor) {
    let path = NSBezierPath(); path.lineWidth = width; path.lineCapStyle = .round; path.lineJoinStyle = .round
    path.move(to: points[0]); for point in points.dropFirst() { path.line(to: point) }
    ink.setStroke(); path.stroke()
}
func icon(size: CGFloat) {
    let t = NSAffineTransform(); t.scale(by: size / 1024); t.concat()
    let tile = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 196, yRadius: 196)
    tile.addClip()
    NSGraphicsContext.current?.imageInterpolation = .high
    logo.draw(in: NSRect(x: 80, y: 80, width: 864, height: 864))
}
let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let logo = NSImage(contentsOf: source.appendingPathComponent("Resources/Distribution/paperclip-logo.png"))!
let iconset = output.appendingPathComponent("TodoAI.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        try render("TodoAI.iconset/icon_\(size)x\(size)\(suffix).png",width: size,height: size,scale: scale) { icon(size: CGFloat(size)) }
    }
}
func text(_ value: String, top: CGFloat, size: CGFloat, ink: NSColor, weight: NSFont.Weight = .regular) {
    let style = NSMutableParagraphStyle(); style.alignment = .center
    (value as NSString).draw(in: NSRect(x: 30, y: 480 - top - 30, width: 660, height: 34), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: ink, .paragraphStyle: style
    ])
}
for scale in [1, 2] {
    let suffix = scale == 2 ? "@2x" : ""
    try render("installer-background\(suffix).png",width: 720,height: 480,scale: scale) {
        color(0.95, 0.97, 0.96).setFill(); NSRect(x: 0,y: 0,width: 720,height: 480).fill()
        text("Next One",top: 32,size: 32,ink: color(0.12,0.25,0.20),weight: .semibold)
        text("Your tasks. Your agent. One shared context.",top: 79,size: 14,ink: color(0.36,0.46,0.40))
        let ink = color(0.28,0.49,0.40)
        stroke([NSPoint(x: 307,y: 260),NSPoint(x: 413,y: 260)],width: 5,ink: ink)
        stroke([NSPoint(x: 393,y: 280),NSPoint(x: 413,y: 260),NSPoint(x: 393,y: 240)],width: 5,ink: ink)
        text("Drag Next One to Applications",top: 328,size: 19,ink: color(0.12,0.25,0.20),weight: .medium)
        text("将左侧应用拖入右侧 Applications 文件夹",top: 362,size: 14,ink: color(0.38,0.46,0.41))
        text("左のアプリを Applications にドラッグ",top: 391,size: 13,ink: color(0.45,0.52,0.48))
        text("앱을 오른쪽 Applications 폴더로 드래그하세요",top: 418,size: 13,ink: color(0.45,0.52,0.48))
    }
}
