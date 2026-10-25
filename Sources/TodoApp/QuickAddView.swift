import SwiftUI

struct QuickAddView: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var titleFocused: Bool
    private let buttonSize: CGFloat = 44
    private let expandedHeight: CGFloat = 72
    private var expanded: Bool { model.composerExpanded }
    private var canFocus: Bool { expanded && model.selectedID == nil && !model.settings && !model.trash && !model.locked }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                if expanded {
                    form
                        .frame(width: geometry.size.width, height: expandedHeight, alignment: .top)
                        .background(OutsideClickBoundary { collapse() })
                        .transition(.opacity)
                }
                Button {
                    if expanded { model.add() }
                    else { model.expandComposer() }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                        .frame(width: buttonSize, height: buttonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(expanded ? "添加待办" : "展开添加待办")
                .accessibilityLabel(expanded ? "添加待办" : "展开添加待办")
            }
            .frame(width: expanded ? geometry.size.width : buttonSize, height: expanded ? expandedHeight : buttonSize, alignment: .bottomTrailing)
            .background(.primary.opacity(expanded ? 0.04 : 0))
            .clipShape(.rect(cornerRadius: expanded ? 12 : buttonSize / 2))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(height: expanded ? expandedHeight : buttonSize)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .easeInOut(duration: 0.42), value: expanded)
        .onChange(of: canFocus) { if !canFocus { titleFocused = false } }
        .task(id: canFocus) {
            guard canFocus else { return }
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 420)) } catch { return }
            guard canFocus else { return }
            titleFocused = true
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let id = model.parentForNew {
                    Menu {
                        Button("改为普通待办") {
                            model.newProject = model.state.liveTasks.first { $0.id == id }?.projectID ?? "unclassified"
                            model.parentForNew = nil
                        }
                    } label: {
                        Text("子任务 → \(model.state.liveTasks.first { $0.id == id }?.title ?? "父任务已不可用")")
                            .lineLimit(1)
                    }.menuStyle(.borderlessButton).help("子任务归属；可改为普通待办")
                } else {
                    Text("添加到")
                    if model.scope == "all" {
                        Picker("添加到", selection: $model.newProject) {
                            Text("未分类").tag("unclassified")
                            ForEach(model.state.projects) { Text($0.name).tag($0.id) }
                        }.labelsHidden().controlSize(.regular)
                    } else {
                        Text(model.state.projects.first { $0.id == model.newProject }?.name ?? "未分类").lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }.font(.system(size: 13)).frame(height: 24).padding(.trailing, buttonSize)
            TextField("添加待办…", text: $model.newTitle)
                .textFieldStyle(.plain).font(.system(size: 13))
                .focused($titleFocused)
                .onSubmit { model.add() }
                .onExitCommand { collapse() }
                .frame(height: 32)
                .padding(.trailing, buttonSize)
        }.padding(.horizontal, 10).padding(.vertical, 6)
    }

    private func collapse() {
        model.window?.panel.makeFirstResponder(nil)
        titleFocused = false
        model.composerExpanded = false
    }
}
