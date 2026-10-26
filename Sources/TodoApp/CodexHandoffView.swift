import AppKit
import SwiftUI
import TodoCore

@MainActor @Observable final class CodexHandoffSession: Identifiable {
    enum Step { case loading, sourcePath, project, targetPath, prompt }
    let id = UUID()
    let taskID: String
    let store: Store
    let database: URL
    var step = Step.loading
    var projects: [CodexProject] = []
    var sourcePaths: [String] = []
    var sourcePath: String?
    var targetProject: CodexProject?
    var targetPath: String?
    var instruction = ""
    var error: String?
    var busy = false
    var loaded = false
    var cancelled = false
    var sourceProjectID: String?
    var candidates: [CodexProject] = []
    var displayTask: TodoItem?
    var taskHeading: String {
        guard let displayTask else { return "" }
        return [displayTask.shortCode, displayTask.title].compactMap { $0 }.joined(separator: "-")
    }

    init(taskID: String, store: Store, database: URL) {
        self.taskID = taskID; self.store = store; self.database = database
        displayTask = (try? store.snapshot())?.liveTasks.first { $0.id == taskID }
    }

    func reload() async {
        guard !busy else { return }
        busy = true; error = nil; step = .loading
        loaded = false; candidates = []
        defer { busy = false }
        do {
            let database = database
            projects = try await Task.detached { try CodexProjects.read(database: database) }.value
            let snapshot = try store.snapshot()
            guard let task = snapshot.liveTasks.first(where: { $0.id == taskID }) else {
                throw TodoError("codex_task", "该任务已移入回收站")
            }
            sourceProjectID = task.projectID
            displayTask = task
            sourcePaths = snapshot.projects.first(where: { $0.id == task.projectID })?.paths ?? []
            sourcePath = nil; targetProject = nil; targetPath = nil
            loaded = true
            if sourcePaths.count > 1 { step = .sourcePath }
            else if let path = sourcePaths.first { chooseSource(path) }
            else { candidates = projects; step = .project }
        } catch { loaded = false; step = .project; report(error) }
    }

    func chooseSource(_ path: String) {
        error = nil
        do {
            try CodexHandoff.requireDirectory(path)
            sourcePath = normalizedPath(path)
            let matches = CodexHandoff.matching(path, in: projects)
            if matches.count == 1 { chooseTarget(matches[0], path: normalizedPath(path)) }
            else { candidates = matches.isEmpty ? projects : matches; step = .project }
        } catch { step = .sourcePath; report(error) }
    }

    func chooseProject(_ project: CodexProject) {
        error = nil; targetProject = project
        if let sourcePath, project.paths.contains(sourcePath) { chooseTarget(project, path: sourcePath) }
        else if project.paths.count == 1 { chooseTarget(project, path: project.paths[0]) }
        else { step = .targetPath }
    }

    func chooseTarget(_ project: CodexProject, path: String) {
        error = nil; targetProject = project
        do {
            try CodexHandoff.requireDirectory(path)
            targetPath = path; step = .prompt
        } catch { step = .targetPath; report(error) }
    }

    func report(_ error: Error) { self.error = LanguageSettings.shared.describe(error) }

    /// Revalidate the selected target and fresh task/attachments before exposing any context.
    func prepareURL() async throws -> URL {
        guard let targetProject, let targetPath else { throw TodoError("codex_path", "请先选择 Codex 项目。") }
        let database = database
        let current = try await Task.detached { try CodexProjects.read(database: database) }.value
        guard current.contains(where: { $0.id == targetProject.id && $0.paths.contains(targetPath) }) else {
            throw TodoError("codex_path", "Codex 项目目录已变化，请重新选择。")
        }
        try CodexHandoff.requireDirectory(targetPath)
        let snapshot = try store.snapshot()
        guard let task = snapshot.liveTasks.first(where: { $0.id == taskID }) else { throw TodoError("codex_task", "该任务已移入回收站") }
        displayTask = task
        let paths = snapshot.projects.first(where: { $0.id == task.projectID })?.paths ?? []
        guard task.projectID == sourceProjectID, paths == sourcePaths else { throw TodoError("codex_path", "待办的项目目录已变化，请重新选择。") }
        if let sourcePath { try CodexHandoff.requireDirectory(sourcePath) }
        let attachments = try snapshot.attachments.filter { $0.taskID == taskID && !$0.deleted }.map { attachment -> (name: String, path: String) in
            let path = store.attachmentURL(attachment).path
            guard FileManager.default.isReadableFile(atPath: path) else { throw TodoError("codex_attachment", "附件无法读取：\(attachment.filename)") }
            return (attachment.filename, path)
        }
        let message = try CodexHandoff.message(item: task, originPath: sourcePath, targetPath: targetPath,
                                               attachments: attachments, instruction: instruction)
        return try CodexHandoff.url(message: message, targetPath: targetPath)
    }

    func prepareOpen() async -> URL? {
        guard !busy, !cancelled else { return nil }
        busy = true; error = nil
        defer { busy = false }
        do {
            let url = try await prepareURL()
            return cancelled ? nil : url
        } catch { report(error); return nil }
    }

}

@MainActor enum ChatGPTMenuIcon {
    static let image: NSImage = {
        // Blossom mark: bundled vector, used solely to identify the Codex destination.
        let resources = Bundle.main.url(forResource: "TodoAI_TodoApp", withExtension: "bundle").flatMap(Bundle.init(url:)) ?? Bundle.module
        let image = NSImage(contentsOf: resources.url(forResource: "chatgpt", withExtension: "svg")!)!
        image.size = NSSize(width: 16, height: 16)
        let gray = NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            NSColor(calibratedWhite: 0.55, alpha: 1).setFill()
            rect.fill(using: .sourceAtop)
            return true
        }
        gray.isTemplate = false // SwiftUI context menus otherwise render this SVG black in dark mode.
        return gray
    }()
}

struct CodexHandoffView: View {
    @Bindable var session: CodexHandoffSession
    let dismiss: () -> Void
    let submit: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.taskHeading).font(.system(size: 15, weight: .semibold))
                .lineLimit(2).help(session.taskHeading)
            if session.step == .loading { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12) }
            else if session.step == .sourcePath {
                Text(L("选择待办目录")).foregroundStyle(.secondary)
                pathList(session.sourcePaths) { session.chooseSource($0) }
            } else if session.step == .project {
                Text(L("选择 Codex 项目")).foregroundStyle(.secondary)
                if session.loaded && session.candidates.isEmpty {
                    Text(L("没有可选项目，请先在 Codex 添加项目。"))
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(session.candidates) { project in
                                Button { session.chooseProject(project) } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(project.name)
                                        Text(project.paths.joined(separator: "\n")).font(.system(size: 11)).foregroundStyle(.secondary)
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                                }.help(project.paths.joined(separator: "\n"))
                            }
                        }
                    }.frame(maxHeight: 220)
                }
            } else if session.step == .targetPath {
                Text(L("选择会话目录")).foregroundStyle(.secondary)
                if let project = session.targetProject { pathList(project.paths) { session.chooseTarget(project, path: $0) } }
            } else {
                Text(session.targetProject?.name ?? "").fontWeight(.medium)
                Text(session.targetPath ?? "").font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
                Text(L("补充指令（可留空回车）")).foregroundStyle(.secondary)
                HandoffInstructionEditor(text: $session.instruction, submit: submit, cancel: cancel)
                    .frame(height: 108).padding(6).disabled(session.busy)
                    .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                Text(L("Enter 打开 · Shift+Enter 换行；到 Codex 后发送。"))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if let error = session.error { Text(error).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            HStack {
                Button(L("取消"), role: .cancel, action: cancel).keyboardShortcut(.cancelAction)
                if !session.busy { Button(L("重新选择")) { Task { await session.reload() } } }
                Spacer()
                if session.step == .prompt {
                    Button(L("打开 Codex"), action: submit).disabled(session.busy)
                }
            }
        }
        .padding(14).frame(width: 360)
        .font(.system(size: 13)).buttonStyle(.bordered).controlSize(.small).tint(.primary)
        .task { if !session.loaded { await session.reload() } }
        .background(HandoffScrollbarStyler())
    }
    func cancel() { session.cancelled = true; dismiss() }
    func pathList(_ paths: [String], action: @escaping (String) -> Void) -> some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(paths, id: \.self) { path in
                    Button { action(path) } label: { Text(path).frame(maxWidth: .infinity, alignment: .leading).padding(6) }.help(path)
                }
            }
        }.frame(maxHeight: 220)
    }
}

/// NSTextView keeps marked text/IME composition intact and routes only unmarked Return.
struct HandoffInstructionEditor: NSViewRepresentable {
    @Binding var text: String
    let submit: () -> Void
    let cancel: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true; scroll.scrollerStyle = .overlay
        scroll.verticalScroller = ThinScroller(); scroll.drawsBackground = false
        let editor = HandoffTextView()
        editor.isRichText = false; editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false; editor.allowsUndo = true
        editor.font = .systemFont(ofSize: 13); editor.textColor = .labelColor
        editor.drawsBackground = false; editor.textContainerInset = NSSize(width: 2, height: 3)
        editor.isVerticallyResizable = true; editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 340, height: CGFloat.greatestFiniteMagnitude)
        editor.delegate = context.coordinator; editor.string = text
        editor.submit = submit; editor.cancel = cancel
        editor.setAccessibilityLabel(L("补充指令（可留空回车）"))
        scroll.documentView = editor
        DispatchQueue.main.async { editor.window?.makeFirstResponder(editor) }
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? HandoffTextView else { return }
        editor.submit = submit; editor.cancel = cancel
        if editor.string != text && !editor.hasMarkedText() { editor.string = text }
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HandoffInstructionEditor
        init(_ parent: HandoffInstructionEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            if let view = notification.object as? NSTextView { parent.text = view.string }
        }
    }
}
final class HandoffTextView: NSTextView {
    var submit: () -> Void = {}
    var cancel: () -> Void = {}
    override func keyDown(with event: NSEvent) {
        if !hasMarkedText() {
            if event.keyCode == 36 || event.keyCode == 76 {
                if event.modifierFlags.contains(.shift) { insertNewlineIgnoringFieldEditor(nil) }
                else { submit() }
                return
            }
            if event.keyCode == 53 { cancel(); return }
        }
        super.keyDown(with: event)
    }
}

/// Sheets use a separate native hosting tree; reuse the application's scroller policy there too.
private struct HandoffScrollbarStyler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Styler() }
    func updateNSView(_ view: NSView, context: Context) { view.needsLayout = true }
    private final class Styler: NSView {
        override func layout() {
            super.layout()
            if let root = window?.contentView { TodoScrollbarPolicy.apply(to: root) }
        }
    }
}
