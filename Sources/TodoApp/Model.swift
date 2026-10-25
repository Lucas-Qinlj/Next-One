import AppKit
import SwiftUI
import TodoCore

@MainActor @Observable final class AppModel {
    let store: Store
    var codexIntegration: CodexIntegration?
    var integrationError: String?
    var state = Snapshot()
    var scope = "all" { didSet { composerExpanded = false } }
    var selectedID: String? { didSet { if selectedID != nil { composerExpanded = false } } }
    var draft: TodoItem?
    var base: TodoItem?
    @ObservationIgnored private var autosaveTask: Task<Void, Never>?
    var settings = false { didSet { if settings { composerExpanded = false } } }
    var trash = false { didSet { if trash { composerExpanded = false } } }
    var toast: Toast?
    @ObservationIgnored private var toastDismissTask: Task<Void, Never>?
    @ObservationIgnored private var refreshError: String?
    var collapsed: Set<String> = []
    var completedGroups: Set<String> = []
    @ObservationIgnored let dragRegions = NSHashTable<LocalDropRegion>.weakObjects()
    var taskDrag: TaskDrag?
    var projectDrag: ProjectDrag?
    var dropHint: TaskDropHint?
    var taskMerge: TaskMerge?
    var newTitle = ""
    var composerExpanded = false
    var parentForNew: String?
    var newProject = "unclassified"
    var pinned = true { didSet { composerExpanded = false } }
    var locked = false { didSet { composerExpanded = false } }
    var opacity = 0.9
    var growsRight = false
    var growsDown = true
    var window: FloatingController?
    var confirm: Confirmation?
    struct Confirmation: Identifiable { let id = UUID(); var title: String; var detail: String; var action: () -> Void }
    init(store: Store) { self.store = store; refresh() }
    func prepareCodexIntegration() {
        do {
            codexIntegration = try CodexIntegration.prepare(dataDirectory: store.directory)
            integrationError = nil
        } catch {
            codexIntegration = nil
            integrationError = error.localizedDescription
        }
    }
    func refresh() {
        do {
            let snapshot = try store.snapshot()
            refreshError = nil
            if snapshot != state {
                state = snapshot
                if let id = selectedID, !dirty {
                    draft = state.liveTasks.first { $0.id == id }; base = draft
                    if draft == nil { selectedID = nil; notify("该任务已移入回收站", kind: .warning) }
                }
            }
        } catch {
            // A polling failure must not restart the same toast every 0.7 seconds.
            if refreshError != error.localizedDescription { report(error) }
            refreshError = error.localizedDescription
        }
    }
    func notify(_ message: String, kind: Toast.Kind = .success) {
        toastDismissTask?.cancel()
        let next = Toast(message: message, kind: kind)
        toast = next
        toastDismissTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard self?.toast?.id == next.id else { return }
            self?.dismissToast()
        }
    }
    func dismissToast() {
        toastDismissTask?.cancel()
        toastDismissTask = nil
        toast = nil
    }
    func report(_ error: Error) { notify(error.localizedDescription, kind: .error) }
    @discardableResult func run(_ command: String, _ args: [String: String]) -> Bool {
        do {
            let result = try store.execute(command, args); refresh()
            let reopened = result["reopened_ancestors"] as? [String] ?? []
            notify(reopened.isEmpty ? "已保存" : "已保存，\(reopened.count) 个祖先任务恢复为待办", kind: reopened.isEmpty ? .success : .warning)
            return true
        } catch { report(error); return false }
    }
    func select(_ item: TodoItem) {
        guard saveDraft() else { return }
        selectedID = item.id; draft = item; base = item; settings = false; trash = false
    }
    func back() { if saveDraft() { selectedID = nil; draft = nil; base = nil; settings = false; trash = false } }
    func showSettings() { guard saveDraft() else { return }; selectedID = nil; draft = nil; base = nil; settings = true; trash = false }
    var dirty: Bool { draft != base }
    func scheduleAutosave() {
        autosaveTask?.cancel()
        guard dirty else { return }
        let id = selectedID
        autosaveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            guard let self, self.selectedID == id else { return }
            _ = self.saveDraft()
        }
    }
    @discardableResult func saveDraft(cascade: Bool = false) -> Bool {
        autosaveTask?.cancel(); autosaveTask = nil
        guard let draft, let base, draft != base else { return true }
        var args = ["id": draft.id, "expected-revision": String(base.revision)]
        if draft.title != base.title { args["title"] = draft.title }
        if draft.description != base.description { args["description"] = draft.description }
        if draft.status != base.status { args["status"] = draft.status }
        if draft.priority != base.priority { args["priority"] = draft.priority }
        if draft.color != base.color { args["color"] = draft.color }
        if draft.dueDate != base.dueDate { args["due-date"] = draft.dueDate ?? "" }
        if draft.dueAt != base.dueAt { args["due-at"] = draft.dueAt ?? "" }
        if cascade { args["cascade"] = "true" }
        if draft.status == "done", !cascade, state.descendants(draft.id).contains(where: { $0.status != "done" }) {
            confirm = Confirmation(title: "一并完成子任务？", detail: "这个任务还有未完成的后代。确认将一起完成。", action: { [weak self] in _ = self?.saveDraft(cascade: true) }); return false
        }
        do {
            let latest = try store.snapshot().liveTasks.first { $0.id == draft.id }
            if let latest, latest.revision != base.revision {
                var merged = latest
                var conflict = false
                for key in [\TodoItem.title, \.description, \.status, \.priority, \.color] {
                    if draft[keyPath: key] != base[keyPath: key] {
                        conflict = conflict || (latest[keyPath: key] != base[keyPath: key] && latest[keyPath: key] != draft[keyPath: key])
                        merged[keyPath: key] = draft[keyPath: key]
                    }
                }
                if draft.dueAt != base.dueAt || draft.dueDate != base.dueDate {
                    conflict = conflict || ((latest.dueAt != base.dueAt || latest.dueDate != base.dueDate) && (latest.dueAt != draft.dueAt || latest.dueDate != draft.dueDate))
                    merged.dueAt = draft.dueAt; merged.dueDate = draft.dueDate
                }
                if conflict {
                    confirm = Confirmation(title: "同一内容已被其他操作修改", detail: "本次输入仍保留。确认使用本次修改；取消后可继续编辑，不会覆盖外部内容。", action: { [weak self] in
                        self?.base = latest; self?.draft = merged
                        _ = self?.saveDraft(cascade: cascade)
                    })
                    return false
                }
                args["expected-revision"] = String(latest.revision)
            }
            let result = try store.execute("update", args)
            refresh()
            if !(result["reopened_ancestors"] as? [String] ?? []).isEmpty { notify("已恢复相关父任务为待办", kind: .warning) }
        } catch { report(error); return false }
        self.draft = state.liveTasks.first { $0.id == draft.id }; self.base = self.draft; return true
    }
    func reloadDraft() { if let id = selectedID { draft = state.liveTasks.first { $0.id == id }; base = draft; notify("已读取最新内容") } }
    func beginAdding(parent: String? = nil) {
        guard saveDraft() else { return }
        selectedID = nil; draft = nil; base = nil; settings = false; trash = false
        parentForNew = parent
        composerExpanded = true
    }
    func expandComposer() {
        if newTitle.isEmpty && parentForNew == nil && scope != "all" { newProject = scope }
        composerExpanded = true
    }
    func add() {
        var args = ["title": newTitle, "source": "user"]
        if let parentForNew { args["parent"] = parentForNew } else { args["project"] = newProject }
        if run("add", args) {
            newTitle = ""
            if let parentForNew { collapsed.remove(parentForNew) }
            parentForNew = nil
            composerExpanded = false
        }
    }
    func toggle(_ item: TodoItem) {
        var args = ["id": item.id, "expected-revision": String(item.revision)]
        if item.status != "done", !state.descendants(item.id).filter({ $0.status != "done" }).isEmpty {
            confirm = Confirmation(title: "一并完成 \(state.descendants(item.id).filter { $0.status != "done" }.count) 个子任务？", detail: "父任务与未完成后代将一起完成。", action: { [weak self] in args["cascade"] = "true"; self?.run("complete", args) }); return
        }
        args["status"] = item.status == "done" ? "todo" : "done"; _ = run("update", args)
    }
    func delete(_ item: TodoItem) {
        let count = state.descendants(item.id).count + 1
        confirm = Confirmation(title: "移入回收站？", detail: "将移动整个分支，共 \(count) 个任务。可在设置中恢复。", action: { [weak self] in
            guard let self else { return }
            if self.run("delete", ["id": item.id, "expected-revision": String(item.revision)]) { self.selectedID = nil; self.draft = nil; self.base = nil }
        })
    }
    func addAttachment(_ url: URL) {
        guard saveDraft(), let id = selectedID, let item = state.liveTasks.first(where: { $0.id == id }) else { return }
        if run("attachment add", ["id": id, "path": url.path, "expected-revision": String(item.revision)]) { reloadDraft() }
    }
    func chooseAttachment() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image, .movie]; panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { for url in panel.urls { addAttachment(url) } }
    }
    func pasteImage() {
        if let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty { urls.forEach(addAttachment); return }
        guard let data = NSPasteboard.general.data(forType: .tiff), let image = NSBitmapImageRep(data: data), let png = image.representation(using: .png, properties: [:]) else { notify("剪贴板里没有图片或媒体文件", kind: .warning); return }
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        do { try png.write(to: path); defer { try? FileManager.default.removeItem(at: path) }; addAttachment(path) } catch { report(error) }
    }
    func unbindProject(_ project: Project, path: String) {
        confirm = Confirmation(title: "解除目录绑定？", detail: "\(path)\n仅解除此目录与“\(project.name)”的关联，保留项目、待办和磁盘文件。", action: { [weak self] in
            _ = self?.run("project unbind", ["id": project.id, "path": path, "expected-revision": String(project.revision)])
        })
    }
    func bindProject(_ project: Project? = nil, replacing: String? = nil) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            var args = ["path": url.path]
            if let project { args["expected-revision"] = String(project.revision); args[replacing == nil ? "project" : "id"] = project.id }
            if let replacing { args["replace-path"] = replacing }
            _ = run(replacing == nil ? "project bind" : "project update", args)
        }
    }
}
