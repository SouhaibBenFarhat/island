import XCTest
@testable import IslandCore

final class InsertionSpacingTests: XCTestCase {
    private func needsSpace(after character: Character?, inserting text: String = "you@example.com") -> Bool {
        InsertionSpacing.needsLeadingSpace(precedingCharacter: character, insertedText: text)
    }

    // MARK: - When a space is added

    func testAfterALetter() {
        XCTAssertTrue(needsSpace(after: "n"))
    }

    func testAfterADigit() {
        XCTAssertTrue(needsSpace(after: "7"))
    }

    func testAfterSentencePunctuation() {
        // "Note: text", "Hi, text", "Done. text" all read better with a space.
        for character: Character in [":", ",", ".", ";", "!", "?"] {
            XCTAssertTrue(needsSpace(after: character), "expected a space after \(character)")
        }
    }

    func testAfterAClosingBracket() {
        XCTAssertTrue(needsSpace(after: ")"))
    }

    // MARK: - When it isn't

    func testNothingBeforeTheCursor() {
        // Start of the field, or we couldn't read it — never guess.
        XCTAssertFalse(needsSpace(after: nil))
    }

    func testAfterASpace() {
        XCTAssertFalse(needsSpace(after: " "))
    }

    func testAfterANewline() {
        XCTAssertFalse(needsSpace(after: "\n"))
    }

    func testAfterATab() {
        XCTAssertFalse(needsSpace(after: "\t"))
    }

    func testWhenTheInsertedTextAlreadyStartsWithASpace() {
        XCTAssertFalse(needsSpace(after: "n", inserting: " you@example.com"))
    }

    func testWhenTheInsertedTextStartsWithANewline() {
        XCTAssertFalse(needsSpace(after: "n", inserting: "\nBest,\nSouhaib"))
    }

    func testWhenThereIsNothingToInsert() {
        XCTAssertFalse(needsSpace(after: "n", inserting: ""))
    }

    func testAfterAnOpenerOrQuote() {
        for character in InsertionSpacing.noSpaceAfter {
            XCTAssertFalse(needsSpace(after: character), "expected no space after \(character)")
        }
    }

    func testOpenersCoverBracketsAndQuotes() {
        for character: Character in ["(", "[", "{", "<", "\"", "'", "/"] {
            XCTAssertTrue(InsertionSpacing.noSpaceAfter.contains(character))
        }
    }

    // MARK: - prepare

    func testPrepareAddsTheSpace() {
        XCTAssertEqual(
            InsertionSpacing.prepare("you@example.com", precedingCharacter: "n"),
            " you@example.com"
        )
    }

    func testPrepareLeavesTextAloneWhenNoSpaceIsNeeded() {
        XCTAssertEqual(
            InsertionSpacing.prepare("you@example.com", precedingCharacter: " "),
            "you@example.com"
        )
        XCTAssertEqual(
            InsertionSpacing.prepare("you@example.com", precedingCharacter: nil),
            "you@example.com"
        )
    }

    func testPrepareAddsAtMostOneSpace() {
        let once = InsertionSpacing.prepare("x", precedingCharacter: "a")
        let twice = InsertionSpacing.prepare(once, precedingCharacter: "a")
        XCTAssertEqual(once, " x")
        XCTAssertEqual(twice, " x", "already-spaced text must not gain another space")
    }

    func testPrepareKeepsMultilineContentIntact() {
        XCTAssertEqual(
            InsertionSpacing.prepare("Best,\nSouhaib", precedingCharacter: "—"),
            " Best,\nSouhaib"
        )
    }
}
