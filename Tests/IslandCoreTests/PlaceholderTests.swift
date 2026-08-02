import XCTest
@testable import IslandCore

final class PlaceholderTests: XCTestCase {
    // 2026-08-02 14:39:07 UTC
    private let fixedDate = Date(timeIntervalSince1970: 1_785_681_547)
    private let fixedUUID = UUID(uuidString: "6B2B4B1E-9C7B-4E2E-9E2C-2C9C1B7F3A11")!

    private func context(clipboard: String = "") -> PlaceholderContext {
        PlaceholderContext(
            date: fixedDate,
            clipboard: clipboard,
            uuid: fixedUUID,
            timeZone: TimeZone(identifier: "UTC")!
        )
    }

    func testTextWithoutPlaceholdersIsUntouched() {
        let text = "Hello there, nothing to expand."
        XCTAssertEqual(PlaceholderExpander.expand(text, context: context()), text)
    }

    func testDate() {
        XCTAssertEqual(PlaceholderExpander.expand("{{date}}", context: context()), "2026-08-02")
    }

    func testTime() {
        XCTAssertEqual(PlaceholderExpander.expand("{{time}}", context: context()), "14:39")
    }

    func testDateTime() {
        XCTAssertEqual(
            PlaceholderExpander.expand("{{datetime}}", context: context()),
            "2026-08-02 14:39"
        )
    }

    func testCustomDateFormat() {
        XCTAssertEqual(
            PlaceholderExpander.expand("{{date:MMM d, yyyy}}", context: context()),
            "Aug 2, 2026"
        )
    }

    func testClipboard() {
        XCTAssertEqual(
            PlaceholderExpander.expand("ref: {{clipboard}}", context: context(clipboard: "ABC-123")),
            "ref: ABC-123"
        )
    }

    func testUUID() {
        XCTAssertEqual(
            PlaceholderExpander.expand("{{uuid}}", context: context()),
            fixedUUID.uuidString
        )
    }

    func testTokenNamesAreCaseInsensitiveAndTrimmed() {
        XCTAssertEqual(PlaceholderExpander.expand("{{ DATE }}", context: context()), "2026-08-02")
    }

    func testSeveralPlaceholdersInOneString() {
        XCTAssertEqual(
            PlaceholderExpander.expand("On {{date}} at {{time}}.", context: context()),
            "On 2026-08-02 at 14:39."
        )
    }

    func testRepeatedPlaceholder() {
        XCTAssertEqual(
            PlaceholderExpander.expand("{{date}}/{{date}}", context: context()),
            "2026-08-02/2026-08-02"
        )
    }

    func testUnknownTokensAreLeftAlone() {
        // Template languages use the same braces — don't eat other people's syntax.
        let text = "Hi {{ user.name }}, {{#each}}"
        XCTAssertEqual(PlaceholderExpander.expand(text, context: context()), text)
    }

    func testUnclosedMarkerIsLiteral() {
        XCTAssertEqual(
            PlaceholderExpander.expand("start {{date", context: context()),
            "start {{date"
        )
    }

    func testEmptyToken() {
        XCTAssertEqual(PlaceholderExpander.expand("{{}}", context: context()), "{{}}")
    }

    func testSurroundingTextIsPreserved() {
        XCTAssertEqual(
            PlaceholderExpander.expand("a{{date}}b", context: context()),
            "a2026-08-02b"
        )
    }

    func testEmptyString() {
        XCTAssertEqual(PlaceholderExpander.expand("", context: context()), "")
    }
}
