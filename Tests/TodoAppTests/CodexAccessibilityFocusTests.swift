import XCTest
import ApplicationServices
@testable import TodoApp

final class CodexAccessibilityFocusTests: XCTestCase {
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
