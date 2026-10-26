import AppKit
import SwiftUI
import TodoCore

struct TaskDrag {
    let token = UUID()
    let item: TodoItem
    var boardRevision: Int = 0
}
struct ProjectDrag {
    let token = UUID()
    let project: Project
    let boardRevision: Int
}
struct TaskDropHint: Equatable {
    let target: String
    let placement: String
}
struct TaskMerge: Identifiable {
    let id = UUID()
    let source: TodoItem
    let target: TodoItem
}

extension AppModel {
    var mergeTint: Color {
        Color(hue: (0.55 + Double(state.projects.count) * 0.381966).truncatingRemainder(dividingBy: 1), saturation: 0.6, brightness: 0.9)
    }
    func beginTaskDrag(_ item: TodoItem) -> TaskDrag? {
        guard saveDraft(), let current = state.liveTasks.first(where: { $0.id == item.id }) else { return nil }
        let drag = TaskDrag(item: current, boardRevision: state.boardRevision ?? 0)
        taskDrag = drag; projectDrag = nil; dropHint = nil
        return drag
    }
    func endTaskDrag(_ token: UUID) {
        if taskDrag?.token == token { taskDrag = nil; dropHint = nil }
        if projectDrag?.token == token { projectDrag = nil; dropHint = nil }
    }
    func beginProjectDrag(_ project: Project) -> UUID? {
        guard saveDraft(), let current = state.projects.first(where: { $0.id == project.id }) else { return nil }
        let drag = ProjectDrag(project: current, boardRevision: state.boardRevision ?? 0)
        projectDrag = drag; taskDrag = nil; dropHint = nil
        return drag.token
    }
    func placeOnBoard(anchor: String, placement: String) -> Bool {
        let key: String, revision: Int, boardRevision: Int
        if let drag = projectDrag { key = "p:" + drag.project.id; revision = drag.project.revision; boardRevision = drag.boardRevision }
        else if let drag = taskDrag { key = "t:" + drag.item.id; revision = drag.item.revision; boardRevision = drag.boardRevision }
        else { return false }
        taskDrag = nil; projectDrag = nil; dropHint = nil
        var args = ["key": key, "expected-revision": String(revision), "expected-board-revision": String(boardRevision), "placement": placement]
        if placement != "end" { args["anchor"] = anchor }
        return run("board place", args)
    }
    func placement(on target: TodoItem, fraction: CGFloat) -> String? {
        guard let source = taskDrag?.item, source.id != target.id,
              !state.descendants(source.id).contains(where: { $0.id == target.id }) else { return nil }
        if source.projectID == nil && target.projectID == nil && fraction > 0.25 && fraction < 0.75 {
            guard !state.descendants(target.id).contains(where: { $0.id == source.id }) else { return nil }
            return "merge"
        }
        guard (source.status == "done") == (target.status == "done") else { return nil }
        return fraction < 0.5 ? "before" : "after"
    }
    func finishDrop(on target: TodoItem, placement: String) -> Bool {
        guard let source = taskDrag?.item else { return false }
        if placement != "merge", scope == "all", target.projectID == nil, target.parentID == nil, target.status != "done" {
            return placeOnBoard(anchor: "t:" + target.id, placement: placement)
        }
        taskDrag = nil; dropHint = nil
        if placement == "merge" {
            taskMerge = TaskMerge(source: source, target: target)
            return true
        }
        return run("place", ["id": source.id, "expected-revision": String(source.revision),
                             "anchor": target.id, "anchor-revision": String(target.revision), "placement": placement])
    }
    func dropAtEnd(project: String?) -> Bool {
        guard let source = taskDrag?.item else { return false }
        taskDrag = nil; dropHint = nil
        let success = run("place", ["id": source.id, "expected-revision": String(source.revision),
                                   "project": project ?? "unclassified", "parent": "root", "placement": "end"])
        if success, let project { collapsed.remove("project-" + project); window?.savePreferences() }
        return success
    }
}

/// Window-local tracking: the same view receives down, dragged and up; no system drag loop.
struct NativeTaskDragSource: NSViewRepresentable {
    let model: AppModel
    var item: TodoItem? = nil
    var project: Project? = nil
    var onClick: (() -> Void)? = nil
    func makeNSView(context: Context) -> SourceView { SourceView() }
    func updateNSView(_ view: SourceView, context: Context) { view.model = model; view.item = item; view.project = project; view.onClick = onClick }
    final class SourceView: NSView {
        weak var model: AppModel?
        var item: TodoItem?
        var project: Project?
        var onClick: (() -> Void)?
        private var down: NSEvent?
        private var token: UUID?
        private var preview: NSPanel?
        private var escapeMonitor: Any?
        private var cursorOffset: CGFloat = 0
        private var cursorOffsetY: CGFloat = 19
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) { cancelDrag(); down = event }
        override func mouseDragged(with event: NSEvent) {
            guard let down, let model, let window else { return }
            if token == nil {
                guard hypot(event.locationInWindow.x - down.locationInWindow.x,
                            event.locationInWindow.y - down.locationInWindow.y) >= 4 else { return }
                if let project { token = model.beginProjectDrag(project) }
                else if let item { token = model.beginTaskDrag(item)?.token }
                guard token != nil else { return }
                let width = max(180, (window.contentView?.bounds.width ?? bounds.width) - 28)
                cursorOffset = min(max(16, convert(down.locationInWindow, from: nil).x + 38), width - 16)
                let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: 38), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
                panel.ignoresMouseEvents = true; panel.isReleasedWhenClosed = false
                panel.level = NSWindow.Level(rawValue: window.level.rawValue + 2)
                cursorOffsetY = 19
                if let project {
                    // Both a gap and a whole block carry boardKey. Never use the gap's
                    // tiny/transparent bounds as the group preview.
                    let region = model.dragRegions.allObjects.first {
                        $0.window === window && $0.boardKey == "p:" + project.id && $0.slotPlacement == nil
                    }
                    let previewWidth = region.map { $0.bounds.width + 20 } ?? width
                    let previewHeight = max(20, region?.bounds.height ?? 60)
                    if let region, let root = window.contentView {
                        let rect = root.convert(region.bounds, from: region).insetBy(dx: -10, dy: 0)
                        let click = root.convert(down.locationInWindow, from: nil)
                        cursorOffset = click.x - rect.minX
                        cursorOffsetY = root.isFlipped ? rect.maxY - click.y : click.y - rect.minY
                    } else { cursorOffsetY = previewHeight - 10 }
                    panel.setContentSize(NSSize(width: previewWidth, height: previewHeight))
                    // Render the same component as the list, rather than caching a
                    // potentially blank layer-backed NSHostingView bitmap.
                    panel.contentView = NSHostingView(rootView:
                        ProjectTaskGroup(model: model, projectID: project.id, name: project.name,
                                         tasks: model.state.children(nil).filter { $0.projectID == project.id && $0.status != "done" },
                                         colorIndex: model.state.projects.firstIndex { $0.id == project.id } ?? 0)
                            .padding(.horizontal, 10)
                            .frame(width: previewWidth, height: previewHeight, alignment: .top)
                            .background(Color(nsColor: .windowBackgroundColor).opacity(0.95), in: .rect(cornerRadius: 7))
                            .allowsHitTesting(false)
                    )
                } else if let item { panel.contentView = NSHostingView(rootView: TaskDragCard(item: item).opacity(0.92)) }
                preview = panel
                escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] key in
                    guard key.keyCode == 53 else { return key }
                    self?.cancelDrag(); return nil
                }
            }
            let screen = window.convertPoint(toScreen: event.locationInWindow)
            preview?.setFrameOrigin(NSPoint(x: screen.x - cursorOffset, y: screen.y - cursorOffsetY))
            preview?.orderFrontRegardless()
            model.updateLocalDrop(at: event.locationInWindow, in: window)
        }
        override func mouseUp(with event: NSEvent) {
            guard let model else { cancelDrag(); return }
            if token != nil, let window {
                model.updateLocalDrop(at: event.locationInWindow, in: window)
                let hint = model.dropHint
                // Remove preview before a move causes the source row to leave the hierarchy.
                closePreview(); down = nil
                if let hint {
                    if hint.placement.hasPrefix("board-") {
                        _ = model.placeOnBoard(anchor: hint.target, placement: String(hint.placement.dropFirst(6)))
                    } else if hint.placement == "end" {
                        _ = model.dropAtEnd(project: hint.target == "end-unclassified" ? nil : String(hint.target.dropFirst(4)))
                    } else if let target = model.state.liveTasks.first(where: { $0.id == hint.target }) {
                        _ = model.finishDrop(on: target, placement: hint.placement)
                    }
                }
                if let token { model.endTaskDrag(token) }
                self.token = nil
            } else {
                let clicked = down != nil && bounds.contains(convert(event.locationInWindow, from: nil))
                down = nil
                if clicked {
                    if let onClick { onClick() } else if let item { model.select(item) }
                }
            }
        }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if window == nil { cancelDrag() } }
        private func closePreview() {
            preview?.orderOut(nil); preview?.close(); preview = nil
            if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor); self.escapeMonitor = nil }
        }
        private func cancelDrag() {
            closePreview()
            if let token { model?.endTaskDrag(token) }
            token = nil; down = nil
        }
    }
}

struct LocalDropRegionView: NSViewRepresentable {
    let model: AppModel
    let taskID: String?
    var projectID: String? = nil
    var boardKey: String? = nil
    var slotPlacement: String? = nil
    func makeNSView(context: Context) -> LocalDropRegion { LocalDropRegion() }
    func updateNSView(_ view: LocalDropRegion, context: Context) {
        view.taskID = taskID; view.projectID = projectID; view.boardKey = boardKey; view.slotPlacement = slotPlacement
        model.dragRegions.add(view)
    }
}
final class LocalDropRegion: NSView {
    var taskID: String?
    var projectID: String?
    var boardKey: String?
    var slotPlacement: String?
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
extension AppModel {
    func updateLocalDrop(at point: NSPoint, in window: NSWindow) {
        dropHint = nil
        var regions = dragRegions.allObjects.filter {
            $0.window === window && !$0.isHiddenOrHasHiddenAncestor &&
            $0.bounds.intersection($0.visibleRect).contains($0.convert(point, from: nil))
        }.sorted {
            @MainActor func rank(_ r: LocalDropRegion) -> Int { r.slotPlacement != nil ? 0 : r.taskID != nil ? 1 : r.boardKey == nil ? 2 : 3 }
            return rank($0) < rank($1)
        }
        // Treat narrow layout gaps beside a slot as that slot, never as the list footer.
        if regions.isEmpty || (taskDrag != nil && regions.allSatisfy { $0.boardKey != nil && $0.slotPlacement == nil }) {
            let nearby = dragRegions.allObjects.compactMap { r -> (LocalDropRegion, CGFloat)? in
                guard r.window === window, r.slotPlacement != nil, !r.isHiddenOrHasHiddenAncestor else { return nil }
                let rect = r.bounds.intersection(r.visibleRect), local = r.convert(point, from: nil)
                guard !rect.isEmpty, local.x >= rect.minX, local.x <= rect.maxX else { return nil }
                let distance = max(rect.minY - local.y, local.y - rect.maxY, 0)
                return distance <= 8 ? (r, distance) : nil
            }.min { $0.1 < $1.1 }
            if let nearby { regions.insert(nearby.0, at: 0) }
        }
        if projectDrag != nil {
            guard let r = regions.first(where: { $0.boardKey != nil }), let key = r.boardKey,
                  key != "p:" + projectDrag!.project.id else { return }
            let placement = r.slotPlacement ?? (r.convert(point, from: nil).y < r.bounds.midY ? "before" : "after")
            if placement == "after", let index = state.boardKeys.firstIndex(of: key), index + 1 < state.boardKeys.count {
                dropHint = TaskDropHint(target: state.boardKeys[index + 1], placement: "board-before")
            } else { dropHint = TaskDropHint(target: key, placement: "board-" + placement) }
            return
        }
        guard let region = regions.first else { return }
        if let key = region.boardKey, let placement = region.slotPlacement {
            guard taskDrag?.item.status != "done", key != "t:" + (taskDrag?.item.id ?? "") else { return }
            dropHint = TaskDropHint(target: key, placement: "board-" + placement)
        } else if let id = region.taskID, let target = state.liveTasks.first(where: { $0.id == id }) {
            let fraction = region.convert(point, from: nil).y / max(1, region.bounds.height)
            dropHint = placement(on: target, fraction: fraction).map { TaskDropHint(target: id, placement: $0) }
        } else if region.boardKey == nil {
            dropHint = TaskDropHint(target: "end-" + (region.projectID ?? "unclassified"), placement: "end")
        }

    }
}

private struct TaskDragCard: View {
    let item: TodoItem
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.status == "done" ? "checkmark.circle" : "circle")
            RoundedRectangle(cornerRadius: 2).fill(taskTint(item.color)).frame(width: 3, height: 24)
            Text(item.title).lineLimit(1)
            Spacer(minLength: 4)
            PriorityBadge(priority: item.priority)
        }.font(.system(size: 13)).padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: 7))
    }
}

struct TaskRowDrag: ViewModifier {
    @Bindable var model: AppModel
    let item: TodoItem
    func body(content: Content) -> some View {
        content
            // Cover the small visual gap as well as the row edge for insertion drops.
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .background { LocalDropRegionView(model: model, taskID: item.id) }
            .overlay {
                if let hint = model.dropHint, hint.target == item.id {
                    if hint.placement == "merge" {
                        RoundedRectangle(cornerRadius: 7).strokeBorder(model.mergeTint, lineWidth: 2).allowsHitTesting(false)
                    } else {
                        VStack(spacing: 0) {
                            if hint.placement == "after" { Spacer(minLength: 0) }
                            Rectangle().fill(Color.accentColor).frame(height: 2)
                            if hint.placement == "before" { Spacer(minLength: 0) }
                        }.allowsHitTesting(false)
                    }
                }
            }
            .popover(isPresented: Binding(get: { model.taskMerge?.target.id == item.id }, set: { if !$0 { model.taskMerge = nil } })) {
                if let merge = model.taskMerge { MergeProjectPopover(model: model, merge: merge) }
            }
            .padding(.vertical, -2)
    }
}

struct BoardDropSlot: View {
    @Bindable var model: AppModel
    let key: String
    let placement: String
    var body: some View {
        Color.clear.frame(height: 6)
            .background { LocalDropRegionView(model: model, taskID: nil, boardKey: key, slotPlacement: placement) }
            .overlay {
                if model.dropHint == TaskDropHint(target: key, placement: "board-" + placement) {
                    Rectangle().fill(Color.cyan).frame(height: 2).allowsHitTesting(false)
                }
            }
    }
}
struct BoardBlock: ViewModifier {
    @Bindable var model: AppModel
    let key: String
    func body(content: Content) -> some View {
        content.background { LocalDropRegionView(model: model, taskID: nil, boardKey: key) }
    }
}

struct ProjectEndDrop: ViewModifier {
    @Bindable var model: AppModel
    let project: String?
    var enabled = true
    func body(content: Content) -> some View {
        content
            .background { if enabled { LocalDropRegionView(model: model, taskID: nil, projectID: project) } }
            .overlay(alignment: .bottom) {
                if enabled && model.dropHint == TaskDropHint(target: "end-" + (project ?? "unclassified"), placement: "end") {
                    Rectangle().fill(Color.accentColor).frame(height: 2).allowsHitTesting(false)
                }
            }
    }
}

struct MergeProjectPopover: View {
    @Bindable var model: AppModel
    let merge: TaskMerge
    @State private var selection = "new"
    @State private var name = ""
    @State private var error: String?
    var emptyProjects: [Project] { model.state.projects.filter { project in !model.state.liveTasks.contains { $0.projectID == project.id } } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("合并到项目")).font(.headline)
            Text(L("“\(merge.target.title)”与“\(merge.source.title)”及其子任务将移入同一个项目。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Picker(L("项目"), selection: $selection) {
                Text(L("创建新项目")).tag("new")
                ForEach(emptyProjects) { Text($0.name).tag($0.id) }
            }
            if selection == "new" {
                TextField(L("项目名称"), text: $name).textFieldStyle(.roundedBorder)
                Text(L("之后可在设置中绑定文件夹。")).font(.caption).foregroundStyle(.secondary)
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            HStack {
                Button(L("取消")) { model.taskMerge = nil }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(L("合并")) {
                    var args = ["id": merge.source.id, "expected-revision": String(merge.source.revision),
                                "target": merge.target.id, "target-revision": String(merge.target.revision)]
                    args[selection == "new" ? "name" : "project"] = selection == "new" ? name : selection
                    do {
                        let result = try model.store.execute("group", args)
                        model.refresh()
                        if let project = result["project"] as? [String: Any], let id = project["id"] as? String { model.collapsed.remove("project-" + id) }
                        model.taskMerge = nil; model.notify(L("已合并到项目"))
                    } catch { self.error = error.localizedDescription }
                }.buttonStyle(.borderedProminent).tint(.blue)
                    .disabled(selection == "new" && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(16).frame(width: 280)
    }
}
