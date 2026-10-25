import AppKit
import SwiftUI

/// Observe this panel's clicks without consuming or replaying them.
struct OutsideClickBoundary: NSViewRepresentable {
    var onOutsideClick: () -> Void

    func makeNSView(context: Context) -> BoundaryView { BoundaryView() }
    func updateNSView(_ view: BoundaryView, context: Context) { view.onOutsideClick = onOutsideClick }

    final class BoundaryView: NSView {
        var onOutsideClick: () -> Void = {}
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
                if let self, event.window === self.window,
                   !self.bounds.contains(self.convert(event.locationInWindow, from: nil)) {
                    self.onOutsideClick()
                }
                return event
            }
        }

        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}
