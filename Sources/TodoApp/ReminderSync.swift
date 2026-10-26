import AppKit
import EventKit
import SwiftUI
import TodoCore

@MainActor @Observable final class ReminderSync {
    struct ListChoice: Identifiable { let id: String; let sourceID: String; let title: String }
    struct Issue: Identifiable { let id: String; let title: String; let kind: String }
    private(set) var lists: [ListChoice] = []
    private(set) var enabled = false
    private(set) var selected = ""
    private(set) var issues: [Issue] = []
    private(set) var problem: String?
    private(set) var busy = false
    private let store: Store
    private let events = EKEventStore()
    private var file: ReminderSyncFile?
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    private var running = false
    private var retryAfter = Date.distantPast
    private var failures = 0
    private var requested = true
    private var lastSnapshot: Snapshot?
    init(store: Store) {
        self.store = store
        do {
            file = try ReminderSyncFile(directory: store.directory)
            enabled = file!.state.enabled; selected = file!.state.calendarID
        } catch { problem = LanguageSettings.shared.describe(error) }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.tick() }
        }
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: events, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.requested = true }
        }
        Task { await tick() }
    }
    private func persist(_ next: ReminderSyncState) throws {
        guard let file else { throw TodoError("sync_storage", "无法打开同步记录。") }
        try file.save(next); enabled = next.enabled; selected = next.calendarID
        refreshIssues()
    }
    private func saveLink(_ id: String, _ link: ReminderLink, state: inout ReminderSyncState) throws {
        guard state.links[id] != link else { return }
        state.links[id] = link; try persist(state)
    }
    func unfinishedCount(_ id: String) -> Int {
        ((try? store.snapshot().descendants(id)) ?? []).filter { $0.status != "done" }.count
    }
    private func refreshIssues() {
        let tasks = (try? store.snapshot().tasks) ?? []
        issues = (file?.state.links ?? [:]).compactMap { id, link in
            guard let issue = link.stopped ? "stopped" : link.issue else { return nil }
            return Issue(id: id, title: tasks.first { $0.id == id }?.title ?? id, kind: issue)
        }.sorted { $0.id < $1.id }
    }
    func loadLists(requestPermission: Bool = false) async {
        guard file != nil else { return }
        busy = true; defer { busy = false }
        do {
            if requestPermission && EKEventStore.authorizationStatus(for: .reminder) != .fullAccess {
                guard try await events.requestFullAccessToReminders() else {
                    throw TodoError("sync_permission", "请在系统设置中允许 Next One 访问提醒事项。")
                }
            }
            guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
                if requestPermission || enabled { problem = L("请在系统设置中允许 Next One 访问提醒事项。") }
                return
            }
            lists = events.calendars(for: .reminder).filter(\.allowsContentModifications).map {
                ListChoice(id: $0.calendarIdentifier, sourceID: $0.source.sourceIdentifier,
                           title: $0.source.title + " · " + $0.title)
            }.sorted { $0.title < $1.title }
            problem = lists.isEmpty ? L("请先在系统提醒事项中创建 iCloud 清单。") : nil
            refreshIssues()
        } catch { problem = LanguageSettings.shared.describe(error) }
    }
    var candidateCount: Int {
        ((try? store.snapshot().liveTasks) ?? []).filter { $0.status != "done" && ($0.dueAt != nil || $0.dueDate != nil) }.count
    }
    var mappedCount: Int { file?.state.links.values.filter { !$0.removed && !$0.stopped }.count ?? 0 }
    func configure(enabled: Bool, target: String) {
        guard !running, var next = file?.state else { return }
        if enabled {
            guard let list = lists.first(where: { $0.id == target }) else { problem = L("请选择 iCloud 提醒事项清单。"); return }
            next.calendarID = list.id; next.sourceID = list.sourceID
        }
        next.enabled = enabled; next.generation += 1
        do { try persist(next); requested = true; retryAfter = .distantPast; problem = nil }
        catch { problem = LanguageSettings.shared.describe(error) }
    }
    var canConfigure: Bool { !running && !busy && file != nil }
    func resolve(_ id: String, keepLocal: Bool, cascade: Bool = false) {
        guard !running, var state = file?.state, var link = state.links[id] else { return }
        do {
            if link.issue == "children", keepLocal, cascade {
                if let task = try store.snapshot().liveTasks.first(where: { $0.id == id }) {
                    _ = try store.execute("complete", ["id": id, "expected-revision": String(task.revision), "cascade": "true"])
                }
            }
            link.issue = nil
            if keepLocal { link.forceLocal = true; link.stopped = false }
            else { link.stopped = true }
            state.links[id] = link
            try persist(state); requested = true; retryAfter = .distantPast
        } catch { problem = LanguageSettings.shared.describe(error) }
    }
    func keepParentIncomplete(_ id: String) { resolve(id, keepLocal: true) }
    private func fetch(_ calendars: [EKCalendar]) async throws -> [EKReminder] {
        let predicate = events.predicateForReminders(in: calendars)
        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            let token = events.fetchReminders(matching: predicate) { values in
                Task { @MainActor in
                    guard !finished else { return }; finished = true
                    if let values { continuation.resume(returning: values) }
                    else { continuation.resume(throwing: TodoError("sync_fetch", "暂时无法读取提醒事项。")) }
                }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(20))
                guard !finished else { return }; finished = true
                events.cancelFetchRequest(token)
                continuation.resume(throwing: TodoError("sync_fetch", "暂时无法读取提醒事项。"))
            }
        }
    }
    func fields(_ reminder: EKReminder) -> ReminderFields {
        var date: String?, instant: String?
        if let components = reminder.dueDateComponents {
            if components.hour == nil {
                if let y = components.year, let m = components.month, let d = components.day { date = String(format: "%04d-%02d-%02d", y, m, d) }
            } else {
                var cal = Calendar(identifier: .gregorian); cal.timeZone = components.timeZone ?? .current
                if let value = cal.date(from: components) { instant = ISO8601DateFormatter().string(from: value) }
            }
        }
        return ReminderFields(title: reminder.title ?? "", notes: reminder.notes ?? "", dueDate: date, dueAt: instant, priority: reminder.priority)
    }
    func apply(_ value: ReminderFields, done: Bool, completedAt: String?, to reminder: EKReminder) {
        reminder.title = value.title; reminder.notes = value.notes; reminder.priority = value.priority
        if let raw = value.dueAt, let date = ISO8601DateFormatter().date(from: raw) {
            var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
            var parts = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            parts.calendar = cal; parts.timeZone = cal.timeZone
            reminder.startDateComponents = parts; reminder.dueDateComponents = parts
        } else if let raw = value.dueDate {
            let parts = raw.split(separator: "-").compactMap { Int($0) }
            if parts.count == 3 {
                let value = DateComponents(calendar: Calendar(identifier: .gregorian), year: parts[0], month: parts[1], day: parts[2])
                reminder.startDateComponents = value; reminder.dueDateComponents = value
            }
        }
        if reminder.isCompleted != done { reminder.isCompleted = done }
        if done, let value = completedAt.flatMap({ ISO8601DateFormatter().date(from: $0) }) { reminder.completionDate = value }
    }
    func updateAlarm(_ reminder: EKReminder, old: ReminderFields?, new: ReminderFields, done: Bool) {
        // Only remove the exact ordinary alarm owned by this bridge, never replace the entire alarms array.
        let oldDate = old?.dueAt.flatMap { ISO8601DateFormatter().date(from: $0) }
        if let oldDate {
            for alarm in reminder.alarms ?? [] where alarm.absoluteDate == oldDate { reminder.removeAlarm(alarm) }
        }
        if !done, let date = new.dueAt.flatMap({ ISO8601DateFormatter().date(from: $0) }), date > Date(),
           !(reminder.alarms ?? []).contains(where: { $0.absoluteDate == date }) {
            reminder.addAlarm(EKAlarm(absoluteDate: date))
        }
    }
    private func pause(_ id: String, _ kind: String, state: inout ReminderSyncState) throws {
        state.links[id]?.issue = kind; try persist(state)
    }
    func tick() async {
        guard enabled, !running, Date() >= retryAfter, var state = file?.state else { return }
        running = true; defer { running = false }
        do {
            guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
                problem = L("请在系统设置中允许 Next One 访问提醒事项。"); return
            }
            let snapshot = try store.snapshot()
            // Always reconcile periodically, even if an OS change notification was missed.
            guard requested || snapshot != lastSnapshot || Date().timeIntervalSince(retryAfter) >= 30 else { return }
            requested = false; lastSnapshot = snapshot
            let calendars = events.calendars(for: .reminder)
            guard let target = calendars.first(where: { $0.calendarIdentifier == state.calendarID && $0.source.sourceIdentifier == state.sourceID && $0.allowsContentModifications }) else {
                problem = L("目标清单不可用，请重新选择。"); return
            }
            let knownIDs = Set(state.links.values.filter { !$0.removed && !$0.stopped }.map(\.calendarID)).union([state.calendarID])
            let known = calendars.filter { knownIDs.contains($0.calendarIdentifier) }
            let reminders = try await fetch(known)
            guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return }
            let byID = Dictionary(reminders.map { ($0.calendarItemIdentifier, $0) }, uniquingKeysWith: { a, _ in a })
            let ids = Set(snapshot.liveTasks.filter { $0.status != "done" && ($0.dueDate != nil || $0.dueAt != nil) }.map(\.id)).union(state.links.keys)
            for id in ids.sorted() {
                guard file?.state.enabled == true, file?.state.generation == state.generation else { return }
                let blocked = state.links.contains { parent, value in
                    value.issue == "children" && parent != id && snapshot.ancestors(id).contains { $0.id == parent }
                }
                if blocked { continue }
                var link = state.links[id] ?? ReminderLink(calendarID: state.calendarID, sourceID: state.sourceID)
                if link.stopped || link.issue != nil { continue }
                if !link.removed && link.itemID != nil && !link.forceLocal && !calendars.contains(where: { $0.calendarIdentifier == link.calendarID && $0.source.sourceIdentifier == link.sourceID }) {
                    state.links[id] = link; try pause(id, "calendar", state: &state); continue
                }
                // Fresh Store read also sees CLI writes occurring while EventKit was fetching.
                var current = try store.snapshot()
                var task = current.liveTasks.first { $0.id == id }
                let marker = state.marker(id)
                let matches = reminders.filter { ($0.notes ?? "").components(separatedBy: "\n").contains(marker) }
                if matches.count > 1 { state.links[id] = link; try pause(id, "duplicate", state: &state); continue }
                var remote = link.itemID.flatMap { byID[$0] ?? (events.calendarItem(withIdentifier: $0) as? EKReminder) } ?? matches.first
                if let remote, !remote.isNew, !remote.refresh() { throw TodoError("sync_fetch", "暂时无法读取提醒事项。") }
                if let found = remote, !(found.notes ?? "").components(separatedBy: "\n").contains(marker) {
                    state.links[id] = link; try pause(id, "identity", state: &state); continue
                }
                let eligible = task.map { $0.dueDate != nil || $0.dueAt != nil } ?? false
                // Do not recreate a disappeared existing object: a phone deletion must be reviewed.
                if eligible, remote == nil, link.itemID != nil, !link.removed, !link.forceLocal {
                    state.links[id] = link; try pause(id, "missing", state: &state); continue
                }
                if !eligible {
                    if let remote {
                        if let baseline = link.fields, fields(remote) != baseline, !link.forceLocal {
                            state.links[id] = link; try pause(id, "edited", state: &state); continue
                        }
                        try events.remove(remote, commit: true)
                    }
                    link.itemID = nil; link.removed = true; link.forceLocal = false
                    try saveLink(id, link, state: &state); continue
                }
                guard var item = task else { continue }
                if link.removed { link = ReminderLink(calendarID: state.calendarID, sourceID: state.sourceID); remote = nil }
                var projection = ReminderFields.project(item, in: current, marker: marker)
                if let remote {
                    if remote.calendar.calendarIdentifier != link.calendarID && !link.forceLocal {
                        state.links[id] = link; try pause(id, "moved", state: &state); continue
                    }
                    switch ReminderDecision.evaluate(link: link, local: projection, localDone: item.status == "done", remote: fields(remote), remoteDone: remote.isCompleted, recurring: remote.hasRecurrenceRules) {
                    case .conflict(let kind): state.links[id] = link; try pause(id, kind, state: &state); continue
                    case .pullCompletion(let done):
                        if done, current.descendants(id).contains(where: { $0.status != "done" }) {
                            state.links[id] = link; try pause(id, "children", state: &state); continue
                        }
                        if done { link.previousStatus = item.status }
                        try store.applyReminderCompletion(id: id, expectedRevision: item.revision, status: done ? "done" : link.previousStatus, completionDate: remote.completionDate)
                        current = try store.snapshot(); task = current.liveTasks.first { $0.id == id }
                        guard let refreshed = task else { continue }; item = refreshed
                        projection = ReminderFields.project(item, in: current, marker: marker)
                    case .publish: break
                    }
                }
                if item.status != "done" { link.previousStatus = item.status }
                if remote == nil && item.status == "done" && state.links[id] == nil { continue }
                // Persist intent before creating: marker adoption recovers save-before-mapping crashes.
                try saveLink(id, link, state: &state)
                let reminder = remote ?? EKReminder(eventStore: events)
                let done = item.status == "done"
                let changed = remote == nil || fields(reminder) != projection || reminder.isCompleted != done || link.completed != done || reminder.calendar.calendarIdentifier != state.calendarID
                if changed {
                    apply(projection, done: done, completedAt: item.completedAt, to: reminder)
                    updateAlarm(reminder, old: link.fields, new: projection, done: done)
                    reminder.calendar = target
                    try events.save(reminder, commit: true)
                }
                link.itemID = reminder.calendarItemIdentifier; link.calendarID = state.calendarID; link.sourceID = state.sourceID
                link.fields = fields(reminder); link.completed = done; link.forceLocal = false; link.removed = false
                try saveLink(id, link, state: &state)
            }
            failures = 0; retryAfter = Date(); problem = nil; refreshIssues()
        } catch {
            failures = min(failures + 1, 6); retryAfter = Date().addingTimeInterval(pow(2, Double(failures)))
            requested = true
            // Ordinary transport failures stay silent. Storage failures need action and must not be lost.
            if let error = error as? TodoError, error.code.hasPrefix("sync_storage") { problem = LanguageSettings.shared.describe(error) }
        }
    }
}
