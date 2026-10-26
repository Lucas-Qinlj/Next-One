import AppKit
import SwiftUI
import TodoCore

final class TaskPanel: NSPanel {
    var inputEnabled = true
    override var canBecomeKey: Bool { inputEnabled }
    override var canBecomeMain: Bool { false }
}
@MainActor final class FloatingController: NSObject {
    let model: AppModel
    let panel: TaskPanel
    let ball: NSPanel
    var geometry: FloatingGeometry
    var expanded = true
    var dragOrigin: CGPoint?
    var mouseOrigin: CGPoint?
    var resizeOrigin: CGSize?
    var resizeMouseOrigin: CGPoint?
    var statusItem: NSStatusItem!
    var timer: Timer?
    let preferencesURL: URL
    init(model: AppModel) {
        self.model = model
        preferencesURL = model.store.directory.appendingPathComponent("window.json")
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        geometry = FloatingGeometry(anchor: CGPoint(x: screen.maxX - 50, y: screen.maxY - 60), size: CGSize(width: 430, height: 560))
        panel = TaskPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        ball = TaskPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        if let data = try? Data(contentsOf: preferencesURL), let p = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let x = p["x"] as? Double, let y = p["y"] as? Double, x.isFinite, y.isFinite { geometry.anchor = CGPoint(x: x, y: y) }
            if let w = p["width"] as? Double, let h = p["height"] as? Double, w.isFinite, h.isFinite { geometry.size = CGSize(width: w, height: h) }
            geometry.growsRight = p["right"] as? Bool ?? false; geometry.growsDown = p["down"] as? Bool ?? true
            model.opacity = min(1, max(0.3, p["opacity"] as? Double ?? 0.9)); model.pinned = p["pinned"] as? Bool ?? true
            model.collapsed = Set(p["collapsed"] as? [String] ?? [])
        }
        for window in [panel, ball] { window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true; window.hidesOnDeactivate = false; window.isReleasedWhenClosed = false }
        panel.title = L("Todo-AI 清单"); ball.title = L("Todo-AI 悬浮球")
        panel.contentView = TodoHostingView(rootView: ContentView(model: model))
        let ballView = BallView(); ballView.controller = self; ball.contentView = ballView
        model.window = self
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Todo-AI")
        statusItem.button?.target = self; statusItem.button?.action = #selector(showMenu)
        refreshLanguage()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshLanguage), name: .todoLanguageChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(systemLanguageChanged), name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        recover()
        applySettings()
        panel.orderFrontRegardless(); ball.orderFrontRegardless()
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.model.refresh() } }
        NotificationCenter.default.addObserver(self, selector: #selector(recover), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(panelResignedKey), name: NSWindow.didResignKeyNotification, object: panel)
    }
    @objc func systemLanguageChanged() { LanguageSettings.shared.refreshSystemLanguage() }
    @objc func refreshLanguage() {
        panel.title = L("Todo-AI 清单"); ball.title = L("Todo-AI 悬浮球")
        (ball.contentView as? BallView)?.refreshLanguage()
        rebuildMainMenu(target: self)
    }
    var currentScreen: CGRect { (NSScreen.screens.first { $0.visibleFrame.contains(geometry.anchor) } ?? NSScreen.main)?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1200, height: 800) }
    func layout() {
        model.growsRight = geometry.growsRight; model.growsDown = geometry.growsDown
        panel.setFrame(geometry.frame, display: true)
        let a = geometry.anchor
        ball.setFrame(CGRect(x: a.x - 22, y: a.y - 22, width: 44, height: 44), display: true)
        ball.contentView?.needsDisplay = true
    }
    @objc func recover() { geometry.fit(in: currentScreen, chooseDirection: true); layout(); ball.orderFrontRegardless(); savePreferences() }
    func toggle() {
        if expanded { guard model.saveDraft() else { return }; panel.orderOut(nil) }
        else { geometry.fit(in: currentScreen, chooseDirection: true); layout(); panel.orderFrontRegardless() }
        expanded.toggle(); ball.orderFrontRegardless()
    }
    func move(to point: CGPoint, start: Bool, end: Bool) {
        if start { mouseOrigin = point; dragOrigin = geometry.anchor }
        if let initial = mouseOrigin, let origin = dragOrigin {
            geometry.anchor = CGPoint(x: origin.x + point.x - initial.x, y: origin.y + point.y - initial.y)
            layout()
        }
        if end { geometry.fit(in: currentScreen, chooseDirection: true); layout(); mouseOrigin = nil; dragOrigin = nil; savePreferences() }
    }
    func eventScreenPoint() -> CGPoint {
        if let event = NSApp.currentEvent, let window = event.window { return window.convertPoint(toScreen: event.locationInWindow) }
        return NSEvent.mouseLocation
    }
    func resize(_ translation: CGSize, horizontal: Bool, vertical: Bool, end: Bool) {
        if resizeOrigin == nil { resizeOrigin = geometry.size; let point = eventScreenPoint(); resizeMouseOrigin = CGPoint(x: point.x - translation.width, y: point.y + translation.height) }
        guard let start = resizeOrigin, let origin = resizeMouseOrigin else { return }
        let pointer = eventScreenPoint()
        let translation = CGSize(width: pointer.x - origin.x, height: origin.y - pointer.y)
        let screen = currentScreen
        let maxW = geometry.growsRight ? screen.maxX - geometry.anchor.x : geometry.anchor.x - screen.minX
        let maxH = geometry.growsDown ? geometry.anchor.y - screen.minY : screen.maxY - geometry.anchor.y
        if horizontal { geometry.size.width = min(maxW, max(340, start.width + translation.width * (geometry.growsRight ? 1 : -1))) }
        if vertical { geometry.size.height = min(maxH, max(300, start.height + translation.height * (geometry.growsDown ? 1 : -1))) }
        layout()
        if end { resizeOrigin = nil; resizeMouseOrigin = nil; savePreferences() }
    }
    func applySettings() {
        if !model.pinned { model.locked = false }
        panel.level = model.pinned ? .floating : .normal
        // A distinct level keeps the ball above the panel even when editing raises the panel.
        ball.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        panel.ignoresMouseEvents = model.locked; panel.inputEnabled = !model.locked
        if model.locked { panel.makeFirstResponder(nil); panel.resignKey() }
        ball.contentView?.needsDisplay = true
        savePreferences()
    }
    func setLocked(_ locked: Bool) {
        guard !locked || model.pinned else { return }
        guard model.saveDraft() else { return }
        model.locked = locked; applySettings()
    }
    func savePreferences() {
        let p: [String: Any] = ["x": geometry.anchor.x, "y": geometry.anchor.y, "width": geometry.size.width, "height": geometry.size.height, "right": geometry.growsRight, "down": geometry.growsDown, "opacity": model.opacity, "pinned": model.pinned, "collapsed": Array(model.collapsed)]
        do { try JSONSerialization.data(withJSONObject: p, options: [.sortedKeys]).write(to: preferencesURL, options: .atomic) } catch { model.report(error) }
    }
    @objc func showMenu() { let menu = makeMenu(); statusItem.menu = menu; statusItem.button?.performClick(nil); statusItem.menu = nil }
    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        for (title, selector) in [(model.locked ? L("解除锁定") : L("锁定穿透"), #selector(lockAction)), (expanded ? L("收起清单") : L("展开清单"), #selector(toggleAction)), (L("设置…"), #selector(settingsAction)), (L("找回悬浮球"), #selector(revealBall)), (L("退出"), #selector(quitAction))] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: ""); item.target = self
            if selector == #selector(lockAction) { item.isEnabled = model.pinned }
            menu.addItem(item)
        }
        menu.autoenablesItems = false; return menu
    }
    @objc func revealBall() { recover(); ball.makeKeyAndOrderFront(nil); ball.makeFirstResponder(ball.contentView) }
    @objc func panelResignedKey() {
        if model.composerExpanded { panel.makeFirstResponder(nil) }
        model.composerExpanded = false
    }
    @objc func lockAction() { setLocked(!model.locked) }
    @objc func toggleAction() { toggle() }
    @objc func settingsAction() { guard model.saveDraft() else { return }; setLocked(false); model.showSettings(); if !expanded { toggle() }; panel.makeKeyAndOrderFront(nil) }
    @objc func quitAction() { if model.saveDraft() { savePreferences(); NSApplication.shared.terminate(nil) } }
}
@MainActor final class BallView: NSView {
    weak var controller: FloatingController?
    var start: CGPoint?
    var dragging = false
    override var acceptsFirstResponder: Bool { true }
    // Preserve the initial mouseDown when another app or window has focus.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func keyDown(with event: NSEvent) { if event.keyCode == 49 || event.keyCode == 36 { controller?.toggle() } else { super.keyDown(with: event) } }
    override init(frame frameRect: NSRect) { super.init(frame: frameRect); setAccessibilityElement(true); setAccessibilityRole(.button); refreshLanguage() }
    func refreshLanguage() {
        setAccessibilityLabel(L("Todo-AI 悬浮球，单击展开或收起，右键解锁"))
        toolTip = L("单击展开/收起 · 拖动移动 · 右键解锁")
    }
    required init?(coder: NSCoder) { fatalError() }
    override func accessibilityPerformPress() -> Bool { controller?.toggle(); return true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.15, green: 0.35, blue: 0.30, alpha: 1).setFill(); NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2)).fill()
        let image = NSImage(systemSymbolName: controller?.model.locked == true ? "lock.fill" : "checklist", accessibilityDescription: nil)!
        image.withSymbolConfiguration(.init(paletteColors: [.white]))?.draw(in: NSRect(x: 12, y: 12, width: 20, height: 20))
    }
    func screenPoint(_ event: NSEvent) -> CGPoint { window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow }
    override func mouseDown(with event: NSEvent) { start = screenPoint(event); dragging = false }
    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }; let point = screenPoint(event)
        if !dragging && hypot(point.x - start.x, point.y - start.y) > 4 { dragging = true; controller?.move(to: start, start: true, end: false) }
        if dragging { controller?.move(to: point, start: false, end: false) }
    }
    override func mouseUp(with event: NSEvent) { if dragging { controller?.move(to: screenPoint(event), start: false, end: true) } else { controller?.toggle() }; start = nil; dragging = false }
    override func rightMouseDown(with event: NSEvent) { if let controller { NSMenu.popUpContextMenu(controller.makeMenu(), with: event, for: self) } }
}
