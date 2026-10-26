import AppKit
import ApplicationServices
import SwiftUI
import TodoCore

@MainActor enum CodexFocusPermission {
    static var granted: Bool { AXIsProcessTrusted() }
    static func openSettings() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

/// Only the explicitly opened prompt is eligible; titles/placeholders and partial text never match.
enum CodexFocusMatch {
    static func matches(role: String?, value: String?, enabled: Bool, focusSettable: Bool, prompt: String) -> Bool {
        guard !normalize(prompt).isEmpty, enabled, focusSettable,
              role == kAXTextAreaRole || role == kAXTextFieldRole, let value else { return false }
        return normalize(value) == normalize(prompt)
    }
    private static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum CodexFocusFailure: String {
    case permission, windowNotReady, searchIncomplete, noMatch, ambiguous, changed, writeRejected, unconfirmed
    @MainActor var message: String {
        switch self {
        case .permission: return L("请开启 Next One 的辅助功能权限，返回后重试。")
        case .windowNotReady: return L("Codex 页面尚未就绪，请重试。")
        case .searchIncomplete: return L("未能完成输入框查找，请手动点击。")
        case .noMatch: return L("未找到与本次指令匹配的输入框，请手动点击。")
        case .ambiguous: return L("找到多个匹配输入框，请手动选择。")
        case .changed: return L("Codex 页面发生变化，请重试。")
        case .writeRejected: return L("Codex 未接受聚焦请求，请手动点击。")
        case .unconfirmed: return L("未能确认输入框焦点，请手动点击。")
        }
    }
}

enum CodexFocusReadback {
    static func ownsKeyboard(targetPID: pid_t, systemPID: pid_t?, appEditorMatches: Bool,
                             systemEditorMatches: Bool, editorFocused: Bool) -> Bool {
        systemPID == targetPID && appEditorMatches && systemEditorMatches && editorFocused
    }
    // AX writes may be acknowledged before the focused-element readback catches up.
    @MainActor static func confirm(check: () -> Bool, stillValid: () -> Bool,
                                  pause: () async throws -> Void = { try await Task.sleep(for: .milliseconds(100)) }) async -> Bool {
        for attempt in 0..<4 {
            guard !Task.isCancelled, stillValid() else { return false }
            if check() { return true }
            if attempt < 3 { do { try await pause() } catch { return false } }
        }
        return false
    }
}

private enum CodexAX {
    static func value(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }
    static func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    static func matches(_ element: AXUIElement, prompt: String) -> Bool {
        let role = value(element, kAXRoleAttribute) as? String
        guard role == kAXTextAreaRole || role == kAXTextFieldRole else { return false }
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, kAXFocusedAttribute as CFString, &settable) == .success else { return false }
        return CodexFocusMatch.matches(role: role, value: value(element, kAXValueAttribute) as? String,
                                      enabled: (value(element, kAXEnabledAttribute) as? Bool) == true,
                                      focusSettable: settable.boolValue, prompt: prompt)
    }
    struct Match { let app: AXUIElement; let window: AXUIElement; let editor: AXUIElement }
    enum Search { case found(Match), failed(CodexFocusFailure) }
    static func find(pid: pid_t, prompt: String, deadline: TimeInterval) -> Search {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.05)
        guard let window = element(value(app, kAXFocusedWindowAttribute)) else { return .failed(.windowNotReady) }
        var queue: [(AXUIElement, Int)] = [(window, 0)], visited: [AXUIElement] = [], found: AXUIElement?
        var index = 0
        while index < queue.count, index < 400 {
            guard !Task.isCancelled, ProcessInfo.processInfo.systemUptime < deadline else { return .failed(.searchIncomplete) }
            let (item, depth) = queue[index]; index += 1
            if visited.contains(where: { CFEqual($0, item) }) { continue }
            visited.append(item)
            if matches(item, prompt: prompt) {
                guard found == nil else { return .failed(.ambiguous) }
                found = item
            }
            var children: CFArray?
            var count: CFIndex = 0
            let childResult = AXUIElementGetAttributeValueCount(item, kAXChildrenAttribute as CFString, &count)
            guard [.success, .attributeUnsupported, .noValue].contains(childResult) else { return .failed(.searchIncomplete) }
            if childResult == .success, count > 0 {
                guard depth < 30, queue.count + count <= 400 else { return .failed(.searchIncomplete) }
                guard AXUIElementCopyAttributeValues(item, kAXChildrenAttribute as CFString, 0, count, &children) == .success else { return .failed(.searchIncomplete) }
                for child in (children as? [AXUIElement]) ?? [] { queue.append((child, depth + 1)) }
            }
        }
        guard ProcessInfo.processInfo.systemUptime < deadline else { return .failed(.searchIncomplete) }
        guard let found else { return .failed(.noMatch) }
        return .found(Match(app: app, window: window, editor: found))
    }
    static func requestFocus(_ match: Match, prompt: String) -> CodexFocusFailure? {
        guard let window = element(value(match.app, kAXFocusedWindowAttribute)), CFEqual(window, match.window),
              matches(match.editor, prompt: prompt) else { return .changed }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.05)
        if let inputApp = element(value(system, kAXFocusedApplicationAttribute)), !CFEqual(inputApp, match.app) {
            // The nonactivating panel may still own keyboard input although Codex is frontmost.
            var inputPID: pid_t = 0
            guard AXUIElementGetPid(inputApp, &inputPID) == .success,
                  inputPID == ProcessInfo.processInfo.processIdentifier else { return .changed }
            guard AXUIElementSetAttributeValue(match.app, kAXFrontmostAttribute as CFString, kCFBooleanTrue) == .success else { return .writeRejected }
        }
        return AXUIElementSetAttributeValue(match.editor, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success ? nil : .writeRejected
    }
    static func isFocused(_ match: Match) -> Bool {
        guard let focused = element(value(match.app, kAXFocusedUIElementAttribute)) else { return false }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.05)
        guard let inputApp = element(value(system, kAXFocusedApplicationAttribute)),
              let input = element(value(system, kAXFocusedUIElementAttribute)) else { return false }
        var targetPID: pid_t = 0, systemPID: pid_t = 0
        guard AXUIElementGetPid(match.app, &targetPID) == .success,
              AXUIElementGetPid(inputApp, &systemPID) == .success else { return false }
        return CodexFocusReadback.ownsKeyboard(targetPID: targetPID, systemPID: systemPID,
            appEditorMatches: CFEqual(focused, match.editor), systemEditorMatches: CFEqual(input, match.editor),
            editorFocused: (value(match.editor, kAXFocusedAttribute) as? Bool) == true)
    }
}

enum CodexFocusOutcome: Equatable {
    case idle, waiting, confirmed, stopped, failed(CodexFocusFailure)
    @MainActor var message: String? {
        switch self {
        case .idle: return nil
        case .waiting: return L("正在确认 Codex 输入焦点…")
        case .confirmed: return L("已确认 Codex 的系统输入焦点。")
        case .stopped: return L("聚焦流程已停止，未确认输入焦点。")
        case .failed(let reason): return reason.message
        }
    }
}

@MainActor @Observable final class CodexAccessibilityFocus {
    private(set) var outcome = CodexFocusOutcome.idle
    @ObservationIgnored
    private var task: Task<Void, Never>?
    @ObservationIgnored
    private var inputMonitor: Any?
    @ObservationIgnored
    private var generation = UUID()
    func cancel() {
        if outcome == .waiting { outcome = .stopped }
        generation = UUID()
        task?.cancel(); task = nil
        if let inputMonitor { NSEvent.removeMonitor(inputMonitor) }
        inputMonitor = nil
    }
    func start(prompt: String, failure onFailure: @escaping (CodexFocusFailure) -> Void) {
        cancel()
        outcome = .waiting
        let failure: (CodexFocusFailure) -> Void = { [weak self] reason in
            self?.outcome = .failed(reason)
            onFailure(reason)
        }
        guard CodexFocusPermission.granted else { failure(.permission); return }
        guard !prompt.isEmpty else { failure(.noMatch); return }
        let generation = generation
        let initialFrontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        inputMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]) { [weak self] event in
            // A character routed to the panel can be the focus bug, not a deliberate cancellation.
            if event.type != .keyDown || event.keyCode == 53 { self?.cancel() }
            return event
        }
        task = Task { [weak self] in
            defer { if self?.generation == generation { self?.cancel() } }
            let deadline = ProcessInfo.processInfo.systemUptime + 4
            var sawCodex = false
            var lastFailure = CodexFocusFailure.windowNotReady
            while !Task.isCancelled, ProcessInfo.processInfo.systemUptime < deadline {
                guard CodexFocusPermission.granted else { failure(.permission); return }
                let front = NSWorkspace.shared.frontmostApplication
                if front?.bundleIdentifier == "com.openai.codex", let pid = front?.processIdentifier {
                    sawCodex = true
                    let worker = Task.detached { CodexAX.find(pid: pid, prompt: prompt, deadline: deadline) }
                    let result = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
                    guard !Task.isCancelled, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
                    switch result {
                    case .failed(let reason): lastFailure = reason
                    case .found(let match):
                        guard CodexFocusPermission.granted else { failure(.permission); return }
                        if let reason = CodexAX.requestFocus(match, prompt: prompt) {
                            lastFailure = reason // A re-rendered editor can be reacquired within the original deadline.
                        } else {
                            let confirmed = await CodexFocusReadback.confirm(check: { CodexAX.isFocused(match) }, stillValid: {
                                CodexFocusPermission.granted && NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
                            })
                            guard !Task.isCancelled, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
                            if !confirmed { failure(CodexFocusPermission.granted ? .unconfirmed : .permission) }
                            else { self?.outcome = .confirmed }
                            return // Never re-write after an acknowledged focus request.
                        }
                    }
                } else if sawCodex || (front?.processIdentifier != initialFrontPID && front?.processIdentifier != ProcessInfo.processInfo.processIdentifier) {
                    return // The user chose another app; never activate Codex to override them.
                }
                do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            }
            if !Task.isCancelled { failure(lastFailure) }
        }
    }
}

struct CodexFocusSettingsView: View {
    @Bindable var model: AppModel
    @State private var granted = CodexFocusPermission.granted
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(L("自动聚焦 Codex 输入框"), isOn: Binding(get: { model.codexAutoFocus }, set: {
                model.codexAutoFocus = $0
                if !$0 { model.codexFocus.cancel() }
                model.window?.savePreferences()
            }))
            if model.codexAutoFocus {
                Text(L("使用辅助功能定位本次预填输入框，只设置焦点，不自动发送。"))
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text(L(granted ? "辅助功能已授权" : "需要辅助功能权限")).font(.caption)
                    Spacer()
                    Button(L("前往授权")) { CodexFocusPermission.openSettings() }
                }
                if let outcome = model.codexFocus.outcome.message {
                    Text(outcome).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            granted = CodexFocusPermission.granted
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)) { _ in
            granted = CodexFocusPermission.granted
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            granted = CodexFocusPermission.granted
        }
    }
}
