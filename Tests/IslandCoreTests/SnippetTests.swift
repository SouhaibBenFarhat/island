import XCTest
@testable import IslandCore

final class SnippetTests: XCTestCase {
    func testDisplayLabelUsesTheLabelWhenItHasOne() {
        let snippet = Snippet(label: "Email", content: "you@example.com")
        XCTAssertEqual(snippet.displayLabel, "Email")
    }

    func testDisplayLabelTrimsWhitespace() {
        let snippet = Snippet(label: "  Email \n", content: "you@example.com")
        XCTAssertEqual(snippet.displayLabel, "Email")
    }

    func testDisplayLabelFallsBackToFirstLineOfContent() {
        let snippet = Snippet(label: "", content: "Best,\nSouhaib")
        XCTAssertEqual(snippet.displayLabel, "Best,")
    }

    func testDisplayLabelFallsBackToUntitledWhenThereIsNothingToShow() {
        XCTAssertEqual(Snippet(label: "   ", content: "").displayLabel, "Untitled")
        XCTAssertEqual(Snippet(label: "", content: "\n\nhello").displayLabel, "Untitled")
    }

    func testDisplayLabelIsTruncated() {
        let long = String(repeating: "a", count: 60)
        let label = Snippet(label: long, content: "").displayLabel
        XCTAssertEqual(label.count, Snippet.labelLimit)
        XCTAssertTrue(label.hasSuffix("…"))
    }

    func testTruncationCountsCharactersNotBytes() {
        // Four emoji, so nothing is cut even though the UTF-16 length is 8.
        XCTAssertEqual(Snippet.truncated("👋🌍🎉🚀", to: 10), "👋🌍🎉🚀")
        XCTAssertEqual(Snippet.truncated("👋🌍🎉🚀", to: 3), "👋🌍…")
    }

    func testTruncationWithNonPositiveLimit() {
        XCTAssertEqual(Snippet.truncated("hello", to: 0), "")
        XCTAssertEqual(Snippet.truncated("hello", to: -3), "")
    }

    func testContentPreviewCollapsesLineBreaks() {
        let snippet = Snippet(label: "Signature", content: "Best,\nSouhaib")
        XCTAssertEqual(snippet.contentPreview, "Best, Souhaib")
    }

    func testContentPreviewCollapsesRunsOfWhitespace() {
        let snippet = Snippet(label: "", content: "a  \t\n  b")
        XCTAssertEqual(snippet.contentPreview, "a b")
    }

    func testContentPreviewOfEmptyContentIsEmpty() {
        XCTAssertEqual(Snippet(label: "x", content: "").contentPreview, "")
        XCTAssertEqual(Snippet(label: "x", content: "   \n ").contentPreview, "")
    }

    func testContentPreviewIsTruncated() {
        let snippet = Snippet(label: "", content: String(repeating: "a", count: 100))
        XCTAssertEqual(snippet.contentPreview.count, Snippet.previewLimit)
        XCTAssertTrue(snippet.contentPreview.hasSuffix("…"))
    }

    func testContentPreviewKeepsShortContentWhole() {
        XCTAssertEqual(Snippet(label: "", content: "you@example.com").contentPreview, "you@example.com")
    }

    func testIsEmptyOnlyLooksAtContent() {
        XCTAssertTrue(Snippet(label: "Named", content: "").isEmpty)
        XCTAssertFalse(Snippet(label: "", content: "x").isEmpty)
    }

    func testCodableRoundTrip() throws {
        let snippet = Snippet(label: "Signature", content: "Best,\nSouhaib")
        let data = try JSONEncoder().encode(snippet)
        let decoded = try JSONDecoder().decode(Snippet.self, from: data)
        XCTAssertEqual(decoded, snippet)
    }
}
