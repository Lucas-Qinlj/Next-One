import AppKit
import SwiftUI

/// Paint only a thin thumb; AppKit retains the original hit area and scrolling behavior.
final class ThinScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { true }

    // The separate, non-interactive indicator paints the thumb without AppKit's overlay fade.
    override func drawKnob() {}

    var visibleKnobRect: NSRect {
        guard isEnabled, knobProportion < 1 else { return .zero }
        var knob = rect(for: .knob)
        guard !knob.isEmpty else { return .zero }
        if bounds.height >= bounds.width {
            knob.origin.x = bounds.maxX - 3
            knob.size.width = 3
        } else {
            knob.origin.y = isFlipped ? bounds.maxY - 3 : bounds.minY
            knob.size.height = 3
        }
        return knob
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if visibleKnobRect.contains(convert(point, from: superview)) { return self }
        return super.hitTest(point)
    }

    override func testPart(_ point: NSPoint) -> NSScroller.Part {
        if visibleKnobRect.contains(convert(point, from: nil)) { return .knob }
        return super.testPart(point)
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

/// Paint independently of the native overlay animator; all input still reaches AppKit.
final class PersistentScrollIndicator: NSView {
    private weak var scrollView: NSScrollView?
    private weak var observedDocument: NSView?
    private var observations: [NSObjectProtocol] = []

    init(scrollView: NSScrollView) {
        self.scrollView = scrollView
        super.init(frame: scrollView.bounds)
        autoresizingMask = [.width, .height]
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override var isOpaque: Bool { false }

    func refresh() {
        guard let scrollView else { return }
        frame = scrollView.bounds
        if observedDocument !== scrollView.documentView || observations.isEmpty {
            observations.forEach(NotificationCenter.default.removeObserver)
            observations.removeAll()
            observedDocument = scrollView.documentView
            scrollView.contentView.postsBoundsChangedNotifications = true
            observedDocument?.postsFrameChangedNotifications = true
            for (name, object) in [(NSView.boundsDidChangeNotification, scrollView.contentView),
                                   (NSView.frameDidChangeNotification, observedDocument)] {
                guard let object else { continue }
                observations.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                    self?.needsDisplay = true
                })
            }
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let scrollView else { return }
        NSColor.labelColor.withAlphaComponent(0.65).setFill()
        for (enabled, scroller) in [(scrollView.hasVerticalScroller, scrollView.verticalScroller),
                                    (scrollView.hasHorizontalScroller, scrollView.horizontalScroller)] {
            guard enabled, let scroller = scroller as? ThinScroller else { continue }
            let knob = scroller.visibleKnobRect
            guard !knob.isEmpty else { continue }
            NSBezierPath(roundedRect: convert(knob, from: scroller), xRadius: 1.5, yRadius: 1.5).fill()
        }
    }

    deinit { observations.forEach(NotificationCenter.default.removeObserver) }
}

/// One host-level policy covers every scroll view, including nested TextEditor views.
final class TodoHostingView<Content: View>: NSHostingView<Content> {
    override func layout() {
        super.layout()
        TodoScrollbarPolicy.apply(to: self)
    }
}

enum TodoScrollbarPolicy {
    static func apply(to view: NSView) {
        if let scroll = view as? NSScrollView {
            // Keep the native hit area over the content, rather than reserving an empty gutter.
            if scroll.scrollerStyle != .overlay { scroll.scrollerStyle = .overlay }
            if let scroller = scroll.verticalScroller, !(scroller is ThinScroller) {
                scroll.verticalScroller = ThinScroller.replacing(scroller)
            }
            if let scroller = scroll.horizontalScroller, !(scroller is ThinScroller) {
                scroll.horizontalScroller = ThinScroller.replacing(scroller)
            }
            if let indicator = scroll.subviews.first(where: { $0 is PersistentScrollIndicator }) as? PersistentScrollIndicator {
                indicator.refresh()
            } else {
                scroll.addSubview(PersistentScrollIndicator(scrollView: scroll), positioned: .above, relativeTo: nil)
            }
        }
        for child in view.subviews { apply(to: child) }
    }
}
