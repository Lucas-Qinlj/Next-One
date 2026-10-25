import AppKit
import TodoCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: FloatingController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let model = AppModel(store: try Store())
            model.prepareCodexIntegration()
            controller = FloatingController(model: model)
            for item in NSApp.mainMenu?.items.first?.submenu?.items ?? [] { item.target = controller }
        }
        catch { let alert = NSAlert(); alert.messageText = "Todo-AI 无法打开"; alert.informativeText = error.localizedDescription; alert.runModal(); NSApp.terminate(nil) }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard controller?.model.saveDraft() != false else { return .terminateCancel }
        controller?.savePreferences(); return .terminateNow
    }
}
MainActor.assumeIsolated {
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
let menu = NSMenu()
let appRoot = NSMenuItem(); let appMenu = NSMenu(title: "TodoAI"); appRoot.submenu = appMenu; menu.addItem(appRoot)
for (title, action, key) in [("找回悬浮球", "revealBall", "b"), ("展开或收起清单", "toggleAction", "t"), ("设置…", "settingsAction", ","), ("退出 TodoAI", "quitAction", "q")] {
    appMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
}
let editRoot = NSMenuItem(); let edit = NSMenu(title: "编辑"); editRoot.submenu = edit; menu.addItem(editRoot)
for (title, action, key) in [("撤销", "undo:", "z"), ("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
    edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
}
app.mainMenu = menu
app.run()

}
