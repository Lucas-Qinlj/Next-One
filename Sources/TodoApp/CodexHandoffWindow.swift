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
        )
        resizeToFit()
        window.center()
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
            window.setFrameOrigin(NSPoint(x: window.frame.minX, y: top - window.frame.height))
        }
    }
    func present() {
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
