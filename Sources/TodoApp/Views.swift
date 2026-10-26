import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ImageIO
import TodoCore

func taskTint(_ value: String) -> Color {
    switch value { case "red": return .red; case "orange": return .orange; case "green": return .green; case "blue": return .blue; case "purple": return .purple; default: return .secondary }
}
@MainActor func label(_ value: String) -> String { ["todo": L("待办"), "in_progress": L("进行中"), "done": L("已完成"), "high": L("紧急"), "medium": L("比较紧急"), "low": L("一般"), "none": L("无"), "red": L("红"), "orange": L("橙"), "green": L("绿"), "blue": L("蓝"), "purple": L("紫")][value] ?? value }
struct IconButton: View {
    let name: String
    let title: String
    var action: () -> Void
    var body: some View { Button(action: action) { Image(systemName: name).frame(width: 26, height: 26) }.buttonStyle(.plain).help(title).accessibilityLabel(title) }
}
struct ContentView: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 14).padding(.top, 18).padding(.bottom, 10)
            Divider()
            ZStack {
                TaskListView(model: model)
                    .opacity(showList ? 1 : 0)
                    .allowsHitTesting(showList)
                    .disabled(!showList)
                    .accessibilityHidden(!showList)
                if model.settings { SettingsView(model: model) }
                else if model.trash { TrashView(model: model) }
                else if model.selectedID != nil { DetailView(model: model) }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(reduceTransparency || contrast == .increased ? 1 : model.opacity))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.14)))
        .overlay { ResizeHandles(model: model) }
        .overlay(alignment: .bottom) {
            Group {
                if let toast = model.toast {
                    ToastView(toast: toast, dismiss: model.dismissToast)
                        .padding(12)
                        .id(toast.id)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }.animation(.easeOut(duration: reduceMotion ? 0.15 : 0.35), value: model.toast?.id)
        }
        .clipShape(.rect(cornerRadius: 16))
        .font(.system(size: 13))
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(.primary)
        .environment(\.locale, LanguageSettings.shared.locale)
        .alert(model.confirm?.title ?? L("确认"), isPresented: Binding(get: { model.confirm != nil }, set: { if !$0 { model.confirm = nil } })) {
            Button(L("确认")) { let action = model.confirm?.action; model.confirm = nil; action?() }
            Button(L("取消"), role: .cancel) { model.confirm = nil }
        } message: { Text(model.confirm?.detail ?? "") }
    }
    var showList: Bool { !model.settings && !model.trash && model.selectedID == nil }
    var header: some View {
        HStack(spacing: 8) {
            if model.selectedID != nil || model.settings || model.trash {
                IconButton(name: "chevron.left", title: L("返回清单")) { model.back() }
                Text(model.settings ? L("设置") : model.trash ? L("回收站") : L("待办详情")).font(.headline)
            } else {
                Picker(L("项目"), selection: $model.scope) {
                    Text(L("全部项目")).tag("all"); Text(L("未分类")).tag("unclassified")
                    ForEach(model.state.projects) { Text($0.name).tag($0.id) }
                }.labelsHidden().controlSize(.regular).font(.system(size: 13))
                    .frame(maxWidth: 190, alignment: .leading)
            }
            Spacer(minLength: 0)
            IconButton(name: model.pinned ? "pin.fill" : "pin", title: model.pinned ? L("取消置顶") : L("置顶")) {
                guard model.saveDraft() else { return }; model.pinned.toggle(); model.window?.applySettings()
            }
            IconButton(name: model.locked ? "lock.fill" : "lock.open", title: model.pinned ? L("锁定穿透（右键球解锁）") : L("置顶后可锁定")) { model.window?.setLocked(!model.locked) }.disabled(!model.pinned)
            IconButton(name: "gearshape", title: L("设置")) { model.showSettings() }
        }
    }
}
struct ResizeHandles: View {
    @Bindable var model: AppModel
    var body: some View {
        ZStack {
            handle(horizontal: true, vertical: false).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: model.growsRight ? (model.growsDown ? .topTrailing : .bottomTrailing) : (model.growsDown ? .topLeading : .bottomLeading))
            handle(horizontal: false, vertical: true).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: model.growsRight ? (model.growsDown ? .bottomLeading : .topLeading) : (model.growsDown ? .bottomTrailing : .topTrailing))
            handle(horizontal: true, vertical: true).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: model.growsRight ? (model.growsDown ? .bottomTrailing : .topTrailing) : (model.growsDown ? .bottomLeading : .topLeading))
        }.allowsHitTesting(!model.locked)
    }
    func handle(horizontal: Bool, vertical: Bool) -> some View {
        Color.clear.frame(width: 16, height: 16).contentShape(Rectangle())
            .help(horizontal && vertical ? L("调整宽高") : horizontal ? L("调整宽度") : L("调整高度"))
            .onHover { hovering in
                let cursor = ResizeCursor.cursor(horizontal: horizontal, vertical: vertical, growsRight: model.growsRight, growsDown: model.growsDown)
                (hovering ? cursor : .arrow).set()
            }
            .gesture(DragGesture(minimumDistance: 1).onChanged { model.window?.resize($0.translation, horizontal: horizontal, vertical: vertical, end: false) }.onEnded { model.window?.resize($0.translation, horizontal: horizontal, vertical: vertical, end: true) })
    }
}
struct TaskListView: View {
    @Bindable var model: AppModel
    var roots: [TodoItem] { model.state.children(nil).filter { model.scope == "all" || ($0.projectID ?? "unclassified") == model.scope } }
    var projectsWithTasks: [Project] {
        let ids = Set(roots.compactMap(\.projectID))
        return model.state.projects.filter { ids.contains($0.id) }
    }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: model.scope == "all" ? 0 : 2) {
                    if model.scope == "all" {
                        ForEach(model.state.boardKeys, id: \.self) { key in
                            BoardDropSlot(model: model, key: key, placement: "before")
                            boardContent(key).modifier(BoardBlock(model: model, key: key))
                        }
                        if let last = model.state.boardKeys.last {
                            BoardDropSlot(model: model, key: last, placement: "after")
                        }
                        TaskGroupView(model: model, tasks: roots.filter { $0.projectID == nil && $0.status == "done" },
                                      depth: 0, groupID: "root-unclassified")
                    } else {
                        TaskGroupView(model: model, tasks: roots, depth: 0, groupID: "root-" + model.scope)
                    }
                    if model.taskDrag != nil && model.scope != "all" {
                        Text(model.scope == "all" || model.scope == "unclassified" ? L("移至未分类末尾") : L("移至项目末尾"))
                            .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .modifier(ProjectEndDrop(model: model, project: model.scope == "all" || model.scope == "unclassified" ? nil : model.scope))
                    }
                }.padding(.horizontal, 14).padding(.vertical, 12)
            }.overlay {
                if roots.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checklist").font(.system(size: 28)).foregroundStyle(.tertiary)
                        Text(L("还没有待办")).font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                        Text(L("写下一件现在要做的事。")).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                }
            }
            QuickAddView(model: model)
                .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 12)
        }
    }
    @ViewBuilder func boardContent(_ key: String) -> some View {
        let id = String(key.dropFirst(2))
        if key.hasPrefix("p:"), let project = model.state.projects.first(where: { $0.id == id }) {
            ProjectTaskGroup(model: model, projectID: id, name: project.name,
                             tasks: roots.filter { $0.projectID == id },
                             colorIndex: model.state.projects.firstIndex(where: { $0.id == id }) ?? 0)
        } else if key.hasPrefix("t:") {
            TaskRow(model: model, taskID: id, depth: 0)
        }
    }

}
struct ProjectTaskGroup: View {
    @Bindable var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    let projectID: String
    let name: String
    let tasks: [TodoItem]
    let colorIndex: Int
    @State private var titleWidth: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var key: String { "project-" + projectID }
    private var isCollapsed: Bool { model.collapsed.contains(key) }
    private var border: Color {
        Color(hue: (0.55 + Double(colorIndex) * 0.381966).truncatingRemainder(dividingBy: 1),
              saturation: colorScheme == .dark ? 0.52 : 0.75,
              brightness: colorScheme == .dark ? 0.88 : 0.60)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.45)) {
                    if !model.collapsed.insert(key).inserted { model.collapsed.remove(key) }
                }
                model.window?.savePreferences()
            } label: {
                Text(name).font(.system(size: 9, weight: .medium)).lineLimit(1)
                    .foregroundStyle(border)
                    .background {
                        GeometryReader { geometry in
                            Color.clear.onAppear { titleWidth = geometry.size.width }
                                .onChange(of: geometry.size.width) { titleWidth = geometry.size.width }
                        }
                    }
                    .frame(height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay {
                if let project = model.state.projects.first(where: { $0.id == projectID }) {
                    NativeTaskDragSource(model: model, project: project, onClick: {
                        withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.45)) {
                            if !model.collapsed.insert(key).inserted { model.collapsed.remove(key) }
                        }
                        model.window?.savePreferences()
                    }).accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 18)
            .help(name + (isCollapsed ? L("：展开项目") : L("：收起项目")))
            .accessibilityLabel(name)
            .accessibilityValue(isCollapsed ? L("已收起") : L("已展开"))
            .modifier(ProjectEndDrop(model: model, project: projectID))
            VStack(alignment: .leading, spacing: 2) {
                TaskGroupView(model: model, tasks: tasks, depth: 0, groupID: key)
            }
            .padding(.horizontal, 10).padding(.top, 2).padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background {
                GeometryReader { geometry in
                    Color.clear.onAppear { contentHeight = geometry.size.height }
                        .onChange(of: geometry.size.height) { contentHeight = geometry.size.height }
                }
            }
            .frame(height: isCollapsed ? 0 : contentHeight, alignment: .top)
            .clipped()
            .allowsHitTesting(!isCollapsed)
            .accessibilityHidden(isCollapsed)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ProjectOutline(titleWidth: titleWidth, collapse: isCollapsed ? 1 : 0)
                .stroke(border, lineWidth: isCollapsed ? 2 : 1).allowsHitTesting(false)
        }
        // Expand the frame around the shared row width instead of narrowing grouped rows.
        .padding(.horizontal, -10)
    }
}

// The top edge has a real gap: no opaque patch behind the project title.
struct ProjectOutline: Shape {
    var titleWidth: CGFloat
    var collapse: CGFloat
    var animatableData: CGFloat {
        get { collapse }
        set { collapse = newValue }
    }
    func path(in rect: CGRect) -> Path {
        let left: CGFloat = 0.5, right = rect.maxX - 0.5
        let top: CGFloat = 10
        let bottom = max(top, rect.maxY - 0.5 - 9.5 * collapse)
        let radius = min(6, (bottom - top) / 2)
        let gapStart: CGFloat = 13
        let gapEnd = min(18 + titleWidth + 5, right - 6)
        let middle = (gapStart + gapEnd) / 2
        let bottomGap = max(0, 1 - (bottom - top) / 10)
        return Path { path in
            path.move(to: CGPoint(x: gapEnd, y: top))
            path.addLine(to: CGPoint(x: right - radius, y: top))
            path.addQuadCurve(to: CGPoint(x: right, y: top + radius), control: CGPoint(x: right, y: top))
            path.addLine(to: CGPoint(x: right, y: bottom - radius))
            path.addQuadCurve(to: CGPoint(x: right - radius, y: bottom), control: CGPoint(x: right, y: bottom))
            path.addLine(to: CGPoint(x: middle + (gapEnd - middle) * bottomGap, y: bottom))
            path.move(to: CGPoint(x: middle + (gapStart - middle) * bottomGap, y: bottom))
            path.addLine(to: CGPoint(x: left + radius, y: bottom))
            path.addQuadCurve(to: CGPoint(x: left, y: bottom - radius), control: CGPoint(x: left, y: bottom))
            path.addLine(to: CGPoint(x: left, y: top + radius))
            path.addQuadCurve(to: CGPoint(x: left + radius, y: top), control: CGPoint(x: left, y: top))
            path.addLine(to: CGPoint(x: gapStart, y: top))
        }
    }
}

struct PriorityBadge: View {
    let priority: String
    private var tint: Color {
        switch priority {
        case "high": Color(red: 0.76, green: 0.16, blue: 0.19)
        case "medium": Color(red: 0.63, green: 0.46, blue: 0.03)
        default: Color(red: 0.12, green: 0.49, blue: 0.29)
        }
    }
    var body: some View {
        Text(label(priority)).font(.caption2).foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(tint, in: RoundedRectangle(cornerRadius: 5))
            .fixedSize().accessibilityLabel(L("优先级：") + label(priority))
    }
}

struct TaskGroupView: View {
    @Bindable var model: AppModel
    let tasks: [TodoItem]
    let depth: Int
    let groupID: String
    var pending: [TodoItem] { tasks.filter { $0.status != "done" } }
    var done: [TodoItem] { tasks.filter { $0.status == "done" } }
    var body: some View {
        ForEach(pending) { TaskRow(model: model, taskID: $0.id, depth: depth) }
        if !done.isEmpty {
            Button {
                if !model.completedGroups.insert(groupID).inserted { model.completedGroups.remove(groupID) }
            } label: { Label(L("已完成 \(done.count)"), systemImage: model.completedGroups.contains(groupID) ? "chevron.down" : "chevron.right").font(.caption).foregroundStyle(.secondary).padding(.leading, CGFloat(min(depth, 6)) * 10 + 4).padding(.vertical, 6) }.buttonStyle(.plain)
            if model.completedGroups.contains(groupID) { ForEach(done) { TaskRow(model: model, taskID: $0.id, depth: depth) } }
        }
    }
}
struct TaskRow: View {
    @Bindable var model: AppModel
    let taskID: String
    let depth: Int
    var children: [TodoItem] { model.state.children(taskID) }
    var body: some View {
        if let item = model.state.liveTasks.first(where: { $0.id == taskID }) {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                IconButton(name: item.status == "done" ? "checkmark.circle.fill" : item.status == "in_progress" ? "circle.lefthalf.filled" : "circle", title: L("\(label(item.status))，点击切换完成状态")) { model.toggle(item) }
                RoundedRectangle(cornerRadius: 2).fill(taskTint(item.color)).frame(width: 3, height: 24)
                Button { model.select(item) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).lineLimit(1).strikethrough(item.status == "done").foregroundStyle(item.status == "done" ? .secondary : .primary)
                        if !children.isEmpty || item.dueDate != nil || item.dueAt != nil || depth >= 6 {
                            HStack(spacing: 8) {
                                if !children.isEmpty { Text("\(children.filter { $0.status == "done" }.count)/\(children.count)") }
                                if let date = item.dueDate { Text(LanguageSettings.shared.date(date, dateOnly: true)) }
                                if let date = item.dueAt.flatMap({ ISO8601DateFormatter().date(from: $0) }) { Text(date, format: .dateTime.month().day().hour().minute()) }
                                if depth >= 6 { Text(L("第 \(depth + 1) 层")) }
                            }.font(.caption2).foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).help(item.title)
                    .overlay { NativeTaskDragSource(model: model, item: item).accessibilityHidden(true) }
                if !children.isEmpty {
                    IconButton(name: model.collapsed.contains(item.id) ? "chevron.right" : "chevron.down", title: L("展开或收起子任务")) {
                        if !model.collapsed.insert(item.id).inserted { model.collapsed.remove(item.id) }; model.window?.savePreferences()
                    }
                }
                PriorityBadge(priority: item.priority)
            }.padding(.leading, CGFloat(min(depth, 6)) * 10).padding(.vertical, 3)
                .modifier(TaskRowDrag(model: model, item: item))
                .contextMenu {
                    Button(L("新增子任务")) { model.beginAdding(parent: item.id) }
                    Menu(L("优先级")) { ForEach(["low", "medium", "high"], id: \.self) { p in Button(label(p)) { _ = model.run("update", ["id": item.id, "expected-revision": String(item.revision), "priority": p]) } } }
                    Menu(L("颜色")) { ForEach(["none", "red", "orange", "green", "blue", "purple"], id: \.self) { color in Button(label(color)) { _ = model.run("update", ["id": item.id, "expected-revision": String(item.revision), "color": color]) } } }
                    Button(L("移动…")) { model.select(item) }
                    Button(L("移入回收站"), role: .destructive) { model.delete(item) }
                }
            if !children.isEmpty && !model.collapsed.contains(item.id) { TaskGroupView(model: model, tasks: children, depth: depth + 1, groupID: item.id) }
        }
        }
    }
}
struct DetailView: View {
    @Bindable var model: AppModel
    @State private var moveProject = "unclassified"
    @State private var moveParent = "root"
    @State private var showMove = false
    @State private var dueKind = "none"
    @State private var due = Date()
    var body: some View {
        ScrollView {
            if let item = model.draft {
                VStack(alignment: .leading, spacing: 16) {
                    let ancestors = model.state.ancestors(item.id)
                    if !ancestors.isEmpty {
                        Text(ancestors.reversed().map(\.title).joined(separator: " / "))
                            .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    detailCard {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField(L("标题"), text: field(\TodoItem.title), axis: .vertical)
                                .font(.system(size: 20, weight: .semibold))
                                .textFieldStyle(.plain).lineLimit(1...4)
                                .accessibilityLabel(L("标题"))
                            GrowingNotesEditor(text: field(\TodoItem.description))
                        }.padding(12)
                    }
                    detailCard {
                        detailRow(L("状态"), icon: "checkmark.circle") {
                            Picker(L("状态"), selection: field(\TodoItem.status)) {
                                ForEach(["todo", "in_progress", "done"], id: \.self) { Text(label($0)).tag($0) }
                            }.labelsHidden()
                        }
                        detailDivider
                        detailRow(L("优先级"), icon: "exclamationmark.3") {
                            Picker(L("优先级"), selection: field(\TodoItem.priority)) {
                                ForEach(["low", "medium", "high"], id: \.self) { Text(label($0)).tag($0) }
                            }.labelsHidden()
                        }
                        detailDivider
                        detailRow(L("颜色"), icon: "circle.lefthalf.filled") {
                            Picker(L("颜色"), selection: field(\TodoItem.color)) {
                                ForEach(["none", "red", "orange", "green", "blue", "purple"], id: \.self) { Text(label($0)).tag($0) }
                            }.labelsHidden()
                        }
                    }
                    detailCard {
                        detailRow(L("截止"), icon: "calendar") {
                            Picker(L("截止"), selection: $dueKind) {
                                Text(L("无")).tag("none"); Text(L("日期")).tag("date"); Text(L("具体时间")).tag("time")
                            }.labelsHidden().onChange(of: dueKind) { updateDue() }
                        }
                        if dueKind != "none" {
                            detailDivider
                            DatePicker(L("截止时间"), selection: $due, displayedComponents: dueKind == "date" ? [.date] : [.date, .hourAndMinute])
                                .labelsHidden().datePickerStyle(.field).controlSize(.small)
                                .frame(maxWidth: .infinity, alignment: .trailing).padding(12)
                                .onChange(of: due) { updateDue() }
                        }
                    }
                    attachmentArea(item)
                    detailCard {
                        detailRow(L("子任务"), icon: "checklist") {
                            Button(L("添加")) { model.beginAdding(parent: item.id) }
                                .help(L("添加子任务")).accessibilityLabel(L("添加子任务"))
                        }
                        ForEach(model.state.children(item.id)) { child in
                            detailDivider
                            HStack(spacing: 8) {
                                IconButton(name: child.status == "done" ? "checkmark.circle" : "circle", title: L("切换完成状态")) { model.toggle(child) }
                                Button(child.title) { model.select(child); loadDue() }
                                    .buttonStyle(.plain).lineLimit(2)
                                Spacer(minLength: 0)
                            }.padding(.horizontal, 10).padding(.vertical, 6)
                        }
                    }
                    detailCard {
                        Button {
                            showMove.toggle(); moveProject = item.projectID ?? "unclassified"; moveParent = item.parentID ?? "root"
                        } label: {
                            detailRow(L("移动…"), icon: "folder") {
                                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        if showMove { detailDivider; moveArea(item).padding(12) }
                    }
                    Button(role: .destructive) { model.delete(item) } label: {
                        Label(L("移入回收站"), systemImage: "trash").frame(maxWidth: .infinity).padding(.vertical, 11)
                    }
                    .buttonStyle(.plain).foregroundStyle(.red)
                    .background(.primary.opacity(0.035), in: .rect(cornerRadius: 12))
                    Text(L("创建于 \(LanguageSettings.shared.date(item.createdAt)) · \(item.source == "codex" ? "Codex" : L("用户")) · 版本 \(item.revision)"))
                        .font(.system(size: 10)).foregroundStyle(.tertiary).padding(.horizontal, 4)
                }.padding(.horizontal, 12).padding(.vertical, 12)
            }
        }
        .onAppear { loadDue() }.onChange(of: model.selectedID) { loadDue() }
    }
    func detailCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.primary.opacity(0.035), in: .rect(cornerRadius: 12))
    }
    var detailDivider: some View { Divider().overlay(.primary.opacity(0.02)).padding(.leading, 40).padding(.trailing, 12) }
    func detailRow<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(.secondary).frame(width: 18)
            Text(title).font(.system(size: 13)).fixedSize()
            Spacer(minLength: 6)
            content().controlSize(.small).buttonStyle(.borderless).pickerStyle(.menu)
                .fixedSize(horizontal: true, vertical: false)
        }.padding(.horizontal, 12).padding(.vertical, 11)
    }
    func field(_ key: WritableKeyPath<TodoItem, String>) -> Binding<String> { Binding(get: { model.draft?[keyPath: key] ?? "" }, set: { model.draft?[keyPath: key] = $0; model.scheduleAutosave() }) }
    func loadDue() {
        if let raw = model.draft?.dueDate { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = Calendar(identifier: .gregorian); f.dateFormat = "yyyy-MM-dd"; due = f.date(from: raw) ?? Date(); dueKind = "date" }
        else if let raw = model.draft?.dueAt { due = ISO8601DateFormatter().date(from: raw) ?? Date(); dueKind = "time" }
        else { dueKind = "none" }
    }
    func updateDue() {
        if dueKind == "date" { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; model.draft?.dueDate = f.string(from: due); model.draft?.dueAt = nil }
        else if dueKind == "time" { model.draft?.dueAt = ISO8601DateFormatter().string(from: due); model.draft?.dueDate = nil }
        else { model.draft?.dueAt = nil; model.draft?.dueDate = nil }
        model.scheduleAutosave()
    }
    func attachmentArea(_ item: TodoItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) { Image(systemName: "photo").font(.system(size: 16)).foregroundStyle(.secondary).frame(width: 18); Text(L("附件")); Spacer(); Button(L("粘贴图片")) { model.pasteImage() }; Button(L("添加…")) { model.chooseAttachment() } }.buttonStyle(.borderless)
            Text(L("图片 / 视频 · 每个文件最大 100 MB · 可拖入此处")).font(.caption2).foregroundStyle(.secondary)
            ForEach(model.state.attachments.filter { $0.taskID == item.id }) { a in
                HStack(spacing: 8) {
                    if !a.deleted {
                        AttachmentThumbnail(url: model.store.attachmentURL(a), image: UTType(a.mediaType)?.conforms(to: .image) == true)
                        Button { if !NSWorkspace.shared.open(model.store.attachmentURL(a)) { model.notify(L("没有可打开此媒体的应用；任务仍可编辑。"), kind: .error) } } label: { Text(a.filename).lineLimit(1) }.buttonStyle(.plain).help(L("打开预览：\(a.filename)"))
                        Spacer()
                        IconButton(name: "trash", title: L("移除附件，可恢复")) { attachmentChange(a, deleting: true) }
                    } else { Text(L("已移除：\(a.filename)")).font(.caption).lineLimit(1); Spacer(); Button(L("恢复")) { attachmentChange(a, deleting: false) } }
                }
            }
        }.padding(12).background(.primary.opacity(0.035), in: .rect(cornerRadius: 12))
            .dropDestination(for: URL.self) { urls, _ in urls.forEach(model.addAttachment); return !urls.isEmpty }
    }
    func attachmentChange(_ attachment: Attachment, deleting: Bool) {
        guard model.saveDraft(), let item = model.draft else { return }
        if model.run(deleting ? "attachment delete" : "attachment restore", ["id": item.id, "attachment": attachment.id, "expected-revision": String(item.revision)]) { model.reloadDraft() }
    }
    func moveArea(_ item: TodoItem) -> some View {
        VStack {
            Picker(L("目标项目"), selection: $moveProject) { Text(L("未分类")).tag("unclassified"); ForEach(model.state.projects) { Text($0.name).tag($0.id) } }.onChange(of: moveProject) { moveParent = "root" }
            Picker(L("父任务"), selection: $moveParent) {
                Text(L("根任务")).tag("root")
                ForEach(model.state.liveTasks.filter { candidate in (candidate.projectID ?? "unclassified") == moveProject && candidate.id != item.id && !model.state.descendants(item.id).contains(where: { $0.id == candidate.id }) }) { Text($0.title).tag($0.id) }
            }
            Button(L("移动整个分支")) {
                guard model.saveDraft(), let latest = model.draft else { return }
                if model.run("move", ["id": item.id, "expected-revision": String(latest.revision), "project": moveProject, "parent": moveParent]) { model.reloadDraft(); showMove = false }
            }
        }
    }
}
struct AttachmentThumbnail: View {
    let url: URL
    let image: Bool
    @State private var thumbnail: NSImage?
    var body: some View {
        Group { if let thumbnail { Image(nsImage: thumbnail).resizable().scaledToFit() } else { Image(systemName: image ? "photo" : "film") } }.frame(width: 44, height: 36)
            .task(id: url) {
                guard image, let source = CGImageSourceCreateWithURL(url as CFURL, nil), let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 120, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return }
                thumbnail = NSImage(cgImage: cg, size: .zero)
            }
    }
}
struct SettingsView: View {
    @Bindable var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker(L("语言"), selection: Binding(get: { LanguageSettings.shared.preference }, set: {
                    do { try LanguageSettings.shared.select($0) } catch { model.report(error) }
                })) {
                    Text(L("跟随系统")).tag("system")
                    Text("简体中文").tag("zh-Hans")
                    Text("English").tag("en")
                    Text("日本語").tag("ja")
                    Text("한국어").tag("ko")
                }
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("背景不透明度 \(Int(model.opacity * 100))%")).font(.system(size: 13, weight: .semibold))
                    Slider(value: $model.opacity, in: 0.3...1).onChange(of: model.opacity) { model.window?.savePreferences() }
                    Text(L("文字和悬浮球保持清晰。")).font(.caption2).foregroundStyle(.secondary)
                }
                Divider()
                HStack(spacing: 8) { Text(L("项目文件夹")).font(.system(size: 13, weight: .semibold)); Spacer(); Button(L("绑定…")) { model.bindProject() } }
                ForEach(model.state.projects) { ProjectSettingsRow(model: model, project: $0) }
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Button(L("打开回收站")) { model.settings = false; model.trash = true }
                    Text(L("删除的分支和附件保留在本机，不自动清理。")).font(.caption2).foregroundStyle(.secondary)
                }
                Divider()
                CodexIntegrationView(model: model)
                Divider()
                Text(L("本版本默认当前桌面，不启用登录启动。锁定时右键球可解锁；菜单栏可找回悬浮球。")).font(.caption2).foregroundStyle(.secondary)
            }.padding(.horizontal, 14).padding(.vertical, 12)
        }
    }
}
struct CodexIntegrationView: View {
    @Bindable var model: AppModel
    private var integration: CodexIntegration? { model.codexIntegration }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("Codex 接入")).font(.system(size: 13, weight: .semibold))
                Spacer()
                if let integration {
                    IconButton(name: "doc.on.doc", title: L("复制 Codex 安装/更新指令")) {
                        let prompt = integration.installPrompt(dataDirectory: model.store.directory, language: LanguageSettings.shared.language)
                        NSPasteboard.general.clearContents()
                        if NSPasteboard.general.setString(prompt, forType: .string) { model.notify(L("安装指令已复制")) }
                        else { model.notify(L("复制失败，请重试"), kind: .error) }
                    }
                }
            }
            Text(L("复制指令到本机 Codex，安装 Skill 与持续工作规则；应用更新后接入内容自动跟随。"))
                .font(.caption).foregroundStyle(.secondary)
            if let integration {
                ScrollView {
                    Text(integration.installPrompt(dataDirectory: model.store.directory, language: LanguageSettings.shared.language))
                        .font(.system(size: 12)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
                .frame(height: 156)
                .background(.primary.opacity(0.04), in: .rect(cornerRadius: 8))
                Text(L("复制不会自动安装；发送后由 Codex 执行。"))
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text(model.integrationError.map { LanguageSettings.shared.describe($0) } ?? L("接入文件尚未准备好。"))
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Button(L("重试")) { model.prepareCodexIntegration() }
            }
        }
    }
}

struct ProjectSettingsRow: View {
    @Bindable var model: AppModel
    let project: Project
    @State private var name = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField(L("项目名称"), text: $name)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(.primary.opacity(0.04), in: .rect(cornerRadius: 8))
                Button(L("改名")) { _ = model.run("project update", ["id": project.id, "name": name, "expected-revision": String(project.revision)]) }
            }
            ForEach(project.paths, id: \.self) { path in
                HStack(spacing: 8) { VStack(alignment: .leading, spacing: 4) { Text(path).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled); if !FileManager.default.fileExists(atPath: path) { Text(L("目录暂不可用，任务仍保留")).font(.caption2).foregroundStyle(.orange) } }; Spacer(minLength: 0); Button(L("重绑")) { model.bindProject(project, replacing: path) }; IconButton(name: "trash", title: L("解除此目录绑定（保留文件和待办）")) { model.unbindProject(project, path: path) }.foregroundStyle(.secondary) }
            }
            Button(project.paths.isEmpty ? L("绑定文件夹…") : L("添加 worktree / 其他绑定目录…")) { model.bindProject(project) }
        }.onAppear { name = project.name }
    }
}
struct TrashView: View {
    @Bindable var model: AppModel
    var roots: [TodoItem] {
        model.state.tasks.filter { item in
            item.deletionID != nil && !model.state.tasks.contains { $0.id == item.parentID && $0.deletionID == item.deletionID }
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if roots.isEmpty { ContentUnavailableView(L("回收站为空"), systemImage: "trash") }
                ForEach(roots) { item in
                    HStack {
                        Text(item.title)
                        Spacer()
                        Button(L("恢复分支")) { _ = model.run("restore", ["id": item.id, "expected-revision": String(item.revision)]) }
                    }
                }
            }.padding(.horizontal, 14).padding(.vertical, 12)
        }
    }
}
