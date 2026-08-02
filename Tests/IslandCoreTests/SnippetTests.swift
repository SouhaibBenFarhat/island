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
        let snippet = Snippet(label: "Signature", content: "Best,\nSouhaib", color: .teal)
        let data = try JSONEncoder().encode(snippet)
        let decoded = try JSONDecoder().decode(Snippet.self, from: data)
        XCTAssertEqual(decoded, snippet)
        XCTAssertEqual(decoded.color, .teal)
    }

    // MARK: - Colour

    func testAnItemStartsWithNoColour() {
        XCTAssertNil(Snippet(label: "Email", content: "x").color)
    }

    func testAnItemSavedBeforeColoursExistedStillLoads() throws {
        let json = Data(#"{"id":"6B2B4B1E-9C7B-4E2E-9E2C-2C9C1B7F3A11","label":"Email","content":"x"}"#.utf8)
        let decoded = try JSONDecoder().decode(Snippet.self, from: json)
        XCTAssertEqual(decoded.label, "Email")
        XCTAssertNil(decoded.color)
    }

    func testAnUnknownColourNameDoesNotThrowAwayTheItem() throws {
        // A palette entry from a newer build, or a hand-edited file.
        let json = Data(#"{"id":"6B2B4B1E-9C7B-4E2E-9E2C-2C9C1B7F3A11","label":"Email","content":"x","color":"chartreuse"}"#.utf8)
        let decoded = try JSONDecoder().decode(Snippet.self, from: json)
        XCTAssertEqual(decoded.label, "Email")
        XCTAssertEqual(decoded.content, "x")
        XCTAssertNil(decoded.color)
    }

    func testAMissingLabelOrContentDecodesAsEmpty() throws {
        let json = Data(#"{"id":"6B2B4B1E-9C7B-4E2E-9E2C-2C9C1B7F3A11"}"#.utf8)
        let decoded = try JSONDecoder().decode(Snippet.self, from: json)
        XCTAssertEqual(decoded.label, "")
        XCTAssertEqual(decoded.content, "")
    }

    // MARK: - Initials

    func testInitialsOfTwoWords() {
        XCTAssertEqual(Snippet(label: "Work Email", content: "x").initials, "WE")
    }

    func testInitialsOfOneWord() {
        XCTAssertEqual(Snippet(label: "Email", content: "x").initials, "E")
    }

    func testInitialsSplitOnDashesAndUnderscores() {
        XCTAssertEqual(Snippet(label: "work-email", content: "x").initials, "WE")
        XCTAssertEqual(Snippet(label: "work_email", content: "x").initials, "WE")
    }

    func testInitialsUseOnlyTheFirstTwoWords() {
        XCTAssertEqual(Snippet(label: "one two three four", content: "x").initials, "OT")
    }

    func testInitialsFallBackThroughTheDisplayLabel() {
        XCTAssertEqual(Snippet(label: "", content: "hello there").initials, "HT")
        XCTAssertEqual(Snippet(label: "", content: "").initials, "U")
    }

    func testInitialsOfAnEmojiLabel() {
        XCTAssertEqual(Snippet(label: "👋 wave", content: "x").initials, "👋W")
    }
}
