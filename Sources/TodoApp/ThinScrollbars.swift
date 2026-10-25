import AppKit
import SwiftUI

/// Paint only a thin thumb; AppKit retains the original hit area and scrolling behavior.
final class ThinScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { true }

    override func drawKnob() {
        guard isEnabled, knobProportion < 1 else { return }
        var knob = rect(for: .knob)
        guard !knob.isEmpty else { return }
        if bounds.height >= bounds.width {
            knob.origin.x = knob.midX - 1.5
            knob.size.width = 3
        } else {
            knob.origin.y = knob.midY - 1.5
            knob.size.height = 3
        }
        NSColor.secondaryLabelColor.setFill()
        NSBezierPath(roundedRect: knob, xRadius: 1.5, yRadius: 1.5).fill()
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}

    static func replacing(_ existing: NSScroller) -> ThinScroller {
        let scroller = ThinScroller(frame: existing.frame)
        scroller.controlSize = existing.controlSize
        scroller.scrollerStyle = existing.scrollerStyle
        scroller.knobStyle = existing.knobStyle
        scroller.target = existing.target
        scroller.action = existing.action
        scroller.doubleValue = existing.doubleValue
        scroller.knobProportion = existing.knobProportion
        scroller.isEnabled = existing.isEnabled
        return scroller
    }
}

/// One host-level policy covers every scroll view, including nested TextEditor views.
final class TodoHostingView<Content: View>: NSHostingView<Content> {
    override func layout() {
        super.layout()
        styleScrollbars(in: self)
    }

    private func styleScrollbars(in view: NSView) {
        if let scroll = view as? NSScrollView {
            if let scroller = scroll.verticalScroller, !(scroller is ThinScroller) {
                scroll.verticalScroller = ThinScroller.replacing(scroller)
            }
            if let scroller = scroll.horizontalScroller, !(scroller is ThinScroller) {
                scroll.horizontalScroller = ThinScroller.replacing(scroller)
            }
        }
        for child in view.subviews { styleScrollbars(in: child) }
    }
}
