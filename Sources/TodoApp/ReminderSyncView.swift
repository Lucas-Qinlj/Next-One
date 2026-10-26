import SwiftUI
import TodoCore

struct ReminderSyncView: View {
    @Bindable var sync: ReminderSync
    @State private var helpVisible = false
    @State private var enabling = false
    @State private var pendingTarget: String?
    @State private var confirming = false
    @State private var disabling = false
    private var explanation: String { L("开启后，有截止日期的待办会同步到所选提醒事项清单，并可在系统日历中显示。请在 Mac 和 iPhone 登录同一 Apple 账户，选择 iCloud 清单，并开启 iCloud「提醒事项」同步和通知权限。日历展示需 macOS 15／iOS 18 或更新版本。\n\n修改、完成和删除会同步，手机勾选或取消完成也会回传。图片、视频及其他附件不同步，子任务独立显示。紧急优先级不会自动开启系统紧急闹钟。关闭同步会保留已有提醒事项。") }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(L("同步到日历")).font(.system(size: 13, weight: .semibold))
                Button { helpVisible.toggle() } label: { Image(systemName: "questionmark.circle") }
                    .buttonStyle(.plain).help(explanation).accessibilityLabel(L("日历同步说明"))
                Spacer()
                Toggle(L("同步到日历"), isOn: Binding(get: { sync.enabled }, set: { on in
                    if on { enabling = true; Task { await sync.loadLists(requestPermission: true) } }
                    else { disabling = true }
                })).labelsHidden().toggleStyle(.switch).disabled(!sync.canConfigure)
            }
            .popover(isPresented: $helpVisible, arrowEdge: .bottom) { Text(explanation).font(.callout).padding(14).frame(width: 330) }
            if enabling || sync.enabled || !sync.selected.isEmpty {
                Picker(L("目标清单"), selection: Binding(get: { sync.selected }, set: { value in
                    pendingTarget = value; confirming = true
                })) {
                    Text(L("选择 iCloud 清单…")).tag("")
                    ForEach(sync.lists) { list in Text(list.title).tag(list.id) }
                    if !sync.selected.isEmpty && !sync.lists.contains(where: { $0.id == sync.selected }) {
                        Text(L("原清单暂不可用")).tag(sync.selected)
                    }
                }.disabled(!sync.canConfigure)
                if enabling && !sync.enabled && !sync.selected.isEmpty {
                    Button(L("开启同步")) { pendingTarget = sync.selected; confirming = true }.disabled(!sync.canConfigure)
                }
            }
            if let problem = sync.problem {
                Text(problem).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(L("重新读取清单")) { Task { await sync.loadLists(requestPermission: true) } }
                    Button(L("打开系统设置")) { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")!) }
                }.disabled(!sync.canConfigure)
            }
            ForEach(sync.issues) { issue in
                VStack(alignment: .leading, spacing: 6) {
                    Text(issue.title).font(.caption).lineLimit(2)
                    Text(issue.kind == "children" ? L("系统侧已完成此父任务，还有 \(sync.unfinishedCount(issue.id)) 条未完成子任务。") : (issue.kind == "stopped" ? L("此条待办已停止同步。") : L("系统侧内容已变化；请选择如何处理此条待办。"))).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        if issue.kind == "stopped" {
                            Button(L("恢复此条同步")) { sync.resolve(issue.id, keepLocal: true) }
                        } else if issue.kind == "children" {
                            Button(L("同时完成子任务")) { sync.resolve(issue.id, keepLocal: true, cascade: true) }
                            Button(L("保持未完成")) { sync.keepParentIncomplete(issue.id) }
                        } else {
                            if issue.kind != "duplicate" && issue.kind != "identity" && issue.kind != "recurring" {
                                Button(L("使用 Next One 内容")) { sync.resolve(issue.id, keepLocal: true) }
                            }
                            Button(L("停止此条同步")) { sync.resolve(issue.id, keepLocal: false) }
                        }
                    }.disabled(!sync.canConfigure)
                }.padding(.vertical, 4)
            }
        }
        .task { await sync.loadLists() }
        .alert(L("确认同步清单"), isPresented: $confirming) {
            Button(L("取消"), role: .cancel) { pendingTarget = nil }
            Button(L("确认")) {
                if let target = pendingTarget { sync.configure(enabled: true, target: target); enabling = false }
                pendingTarget = nil
            }
        } message: {
            Text(L("将同步 \(sync.candidateCount) 条有日期的未完成待办；\(sync.mappedCount) 条已有映射会移至所选清单。包含标题、描述、时间和完成状态，不包含附件。请选择你自己的 iCloud 清单；共享清单中的内容可能被其他成员看到。"))
        }
        .alert(L("停止同步？"), isPresented: $disabling) {
            Button(L("取消"), role: .cancel) { }
            Button(L("停止同步")) { sync.configure(enabled: false, target: sync.selected); enabling = false }
        } message: { Text(L("已有系统提醒事项会保留，仍可能通知；重新开启后继续同步。")) }
    }
}
