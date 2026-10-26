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
    static func find(pid: pid_t, prompt: String, deadline: TimeInterval) -> Match? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.05)
        guard let window = element(value(app, kAXFocusedWindowAttribute)) else { return nil }
        var queue: [(AXUIElement, Int)] = [(window, 0)], visited: [AXUIElement] = [], found: AXUIElement?
        var index = 0
        while index < queue.count, index < 400 {
            guard !Task.isCancelled, ProcessInfo.processInfo.systemUptime < deadline else { return nil }
            let (item, depth) = queue[index]; index += 1
            if visited.contains(where: { CFEqual($0, item) }) { continue }
            visited.append(item)
            if matches(item, prompt: prompt) {
                guard found == nil else { return nil } // Ambiguous: do not choose one.
                found = item
            }
            var children: CFArray?
            var count: CFIndex = 0
            let childResult = AXUIElementGetAttributeValueCount(item, kAXChildrenAttribute as CFString, &count)
            guard [.success, .attributeUnsupported, .noValue].contains(childResult) else { return nil }
            if childResult == .success, count > 0 {
                guard depth < 30, queue.count + count <= 400 else { return nil }
                guard AXUIElementCopyAttributeValues(item, kAXChildrenAttribute as CFString, 0, count, &children) == .success else { return nil }
                for child in (children as? [AXUIElement]) ?? [] { queue.append((child, depth + 1)) }
            }
        }
        guard let found, ProcessInfo.processInfo.systemUptime < deadline else { return nil }
        return Match(app: app, window: window, editor: found)
    }
    static func focus(_ match: Match, prompt: String) -> Bool {
        guard let window = element(value(match.app, kAXFocusedWindowAttribute)), CFEqual(window, match.window),
              matches(match.editor, prompt: prompt),
              AXUIElementSetAttributeValue(match.editor, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success,
              let focused = element(value(match.app, kAXFocusedUIElementAttribute)) else { return false }
        return CFEqual(focused, match.editor) && (value(match.editor, kAXFocusedAttribute) as? Bool) == true
    }
}

@MainActor final class CodexAccessibilityFocus {
    private var task: Task<Void, Never>?
    private var inputMonitor: Any?
    private var generation = UUID()
    func cancel() {
        generation = UUID()
        task?.cancel(); task = nil
        if let inputMonitor { NSEvent.removeMonitor(inputMonitor) }
        inputMonitor = nil
    }
    func start(prompt: String, failure: @escaping () -> Void) {
        cancel()
        guard CodexFocusPermission.granted, !prompt.isEmpty else { failure(); return }
        let generation = generation
        let initialFrontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        inputMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]) { [weak self] event in
            self?.cancel()
            return event
        }
        task = Task { [weak self] in
            defer { if self?.generation == generation { self?.cancel() } }
            let deadline = ProcessInfo.processInfo.systemUptime + 4
            var sawCodex = false
            while !Task.isCancelled, ProcessInfo.processInfo.systemUptime < deadline {
                guard CodexFocusPermission.granted else { failure(); return }
                let front = NSWorkspace.shared.frontmostApplication
                if front?.bundleIdentifier == "com.openai.codex", let pid = front?.processIdentifier {
                    sawCodex = true
                    let worker = Task.detached { CodexAX.find(pid: pid, prompt: prompt, deadline: deadline) }
                    let match = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
                    guard !Task.isCancelled, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
                    if let match {
                        guard CodexFocusPermission.granted else { failure(); return }
                        if !CodexAX.focus(match, prompt: prompt) { failure() }
                        return
                    }
                } else if sawCodex || (front?.processIdentifier != initialFrontPID && front?.processIdentifier != ProcessInfo.processInfo.processIdentifier) {
                    return // The user chose another app; never activate Codex to override them.
                }
                do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            }
            if !Task.isCancelled { failure() }
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
