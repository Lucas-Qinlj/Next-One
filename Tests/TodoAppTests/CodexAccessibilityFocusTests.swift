import XCTest
import ApplicationServices
@testable import TodoApp

final class CodexAccessibilityFocusTests: XCTestCase {
    @MainActor func testDelayedReadbackConfirmsWithoutAnotherFocusWrite() async {
        var reads = 0, pauses = 0
        let result = await CodexFocusReadback.confirm(check: { reads += 1; return reads == 3 },
            stillValid: { true }, pause: { pauses += 1 })
        XCTAssertTrue(result)
        XCTAssertEqual(reads, 3)
        XCTAssertEqual(pauses, 2)
    }
    @MainActor func testReadbackStopsWhenUserLeavesOrPermissionChanges() async {
        var valid = true, reads = 0
        let result = await CodexFocusReadback.confirm(check: { reads += 1; return false },
            stillValid: { valid }, pause: { valid = false })
        XCTAssertFalse(result)
        XCTAssertEqual(reads, 1)
    }
    @MainActor func testReadbackIsBoundedAndCancellationStopsIt() async {
        var reads = 0
        let result = await CodexFocusReadback.confirm(check: { reads += 1; return false },
            stillValid: { true }, pause: {})
        XCTAssertFalse(result)
        XCTAssertEqual(reads, 4)
        reads = 0
        let cancelled = await CodexFocusReadback.confirm(check: { reads += 1; return false },
            stillValid: { true }, pause: { throw CancellationError() })
        XCTAssertFalse(cancelled)
        XCTAssertEqual(reads, 1)
    }
    func testOnlyCompleteEditablePromptMatches() {
        let prompt = "<neo>\nC3 Example\n</neo>\n\nReview only"
        XCTAssertTrue(CodexFocusMatch.matches(role: kAXTextAreaRole, value: prompt, enabled: true, focusSettable: true, prompt: prompt))
        XCTAssertTrue(CodexFocusMatch.matches(role: kAXTextAreaRole, value: prompt.replacingOccurrences(of: "\n", with: "\r\n") + "\n", enabled: true, focusSettable: true, prompt: prompt))
        for value in ["", "Review only", prompt + " edited", "Earlier message\n" + prompt] {
            XCTAssertFalse(CodexFocusMatch.matches(role: kAXTextAreaRole, value: value, enabled: true, focusSettable: true, prompt: prompt))
        }
        XCTAssertFalse(CodexFocusMatch.matches(role: kAXStaticTextRole, value: prompt, enabled: true, focusSettable: true, prompt: prompt))
        XCTAssertFalse(CodexFocusMatch.matches(role: kAXTextAreaRole, value: prompt, enabled: false, focusSettable: true, prompt: prompt))
        XCTAssertFalse(CodexFocusMatch.matches(role: kAXTextAreaRole, value: prompt, enabled: true, focusSettable: false, prompt: prompt))
        XCTAssertFalse(CodexFocusMatch.matches(role: kAXTextAreaRole, value: "", enabled: true, focusSettable: true, prompt: ""))
    }
}
