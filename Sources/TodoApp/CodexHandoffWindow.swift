import AppKit
import SwiftUI

@MainActor final class CodexHandoffWindow: NSWindowController, NSWindowDelegate {
    weak var model: AppModel?
    let session: CodexHandoffSession

    init(model: AppModel, session: CodexHandoffSession) {
        self.model = model; self.session = session
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 160),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = L("创建 Codex 会话")
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.delegate = self
        window.contentView = NSHostingView(rootView:
            CodexHandoffView(session: session, dismiss: { [weak model] in model?.cancelCodexHandoff() }, submit: { [weak model] in
                Task { await model?.openCodexHandoff(session) }
            })
            .fixedSize()
            .onChange(of: session.step) { [weak self] in self?.resizeToFit() }
            .onChange(of: session.error) { [weak self] in self?.resizeToFit() }
            .onChange(of: session.taskHeading) { [weak self] in self?.resizeToFit() }
        )
        resizeToFit()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func resizeToFit() {
        // Let SwiftUI finish applying the changed step before measuring its intrinsic size.
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window, let content = window.contentView else { return }
            content.layoutSubtreeIfNeeded()
            let size = content.fittingSize
            guard size.width > 0, size.height > 0 else { return }
            let top = window.frame.maxY
            window.setContentSize(size)
            let origin = NSPoint(x: window.frame.minX, y: top - window.frame.height)
            window.setFrameOrigin(Self.clamped(origin, size: window.frame.size, screen: self?.placementScreen ?? window.screen?.visibleFrame ?? window.frame))
        }
    }
    private var placementScreen: NSRect {
        model?.window?.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
    }
    static func nearbyOrigin(size: NSSize, panel: NSRect, screen: NSRect) -> NSPoint {
        let right = panel.maxX + 12
        let left = panel.minX - 12 - size.width
        let x: CGFloat
        if right + size.width <= screen.maxX - 8 { x = right }
        else if left >= screen.minX + 8 { x = left }
        else { x = screen.maxX - panel.maxX >= panel.minX - screen.minX ? right : left }
        return clamped(NSPoint(x: x, y: panel.maxY - size.height), size: size, screen: screen)
    }
    private static func clamped(_ origin: NSPoint, size: NSSize, screen: NSRect) -> NSPoint {
        let safe = screen.insetBy(dx: 8, dy: 8)
        return NSPoint(x: min(max(origin.x, safe.minX), max(safe.minX, safe.maxX - size.width)),
                       y: min(max(origin.y, safe.minY), max(safe.minY, safe.maxY - size.height)))
    }
    func present() {
        if let window, let panel = model?.window?.panel {
            window.setFrameOrigin(Self.nearbyOrigin(size: window.frame.size, panel: panel.frame, screen: placementScreen))
        } else { window?.center() }
        resizeToFit()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
    func closeWithoutCallback() {
        window?.delegate = nil
        window?.close()
    }
    func windowWillClose(_ notification: Notification) {
        guard model?.codexHandoff === session else { return }
        session.cancelled = true
        model?.codexHandoff = nil
        model?.codexHandoffWindow = nil
    }
}
