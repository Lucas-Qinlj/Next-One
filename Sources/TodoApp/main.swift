import AppKit
import TodoCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: FloatingController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        LanguageSettings.shared.load(directory: Store.defaultDirectory)
        do {
            let model = AppModel(store: try Store())
            model.prepareCodexIntegration()
            controller = FloatingController(model: model)
            for item in NSApp.mainMenu?.items.first?.submenu?.items ?? [] { item.target = controller }
        }
        catch { let alert = NSAlert(); alert.messageText = L("Todo-AI 无法打开"); alert.informativeText = LanguageSettings.shared.describe(error); alert.runModal(); NSApp.terminate(nil) }
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
rebuildMainMenu(target: nil)
app.run()

}

@MainActor func rebuildMainMenu(target: AnyObject?) {
let menu = NSMenu()
let appRoot = NSMenuItem(); let appMenu = NSMenu(title: "TodoAI"); appRoot.submenu = appMenu; menu.addItem(appRoot)
for (title, action, key) in [(L("找回悬浮球"), "revealBall", "b"), (L("展开或收起清单"), "toggleAction", "t"), (L("设置…"), "settingsAction", ","), (L("退出 TodoAI"), "quitAction", "q")] {
    let item = appMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
    item.target = target
}
let editRoot = NSMenuItem(); let edit = NSMenu(title: L("编辑")); editRoot.submenu = edit; menu.addItem(editRoot)
for (title, action, key) in [(L("撤销"), "undo:", "z"), (L("剪切"), "cut:", "x"), (L("复制"), "copy:", "c"), (L("粘贴"), "paste:", "v"), (L("全选"), "selectAll:", "a")] {
    edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
}
NSApp.mainMenu = menu
}
