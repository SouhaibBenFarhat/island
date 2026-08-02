import XCTest
@testable import IslandCore

final class UnicodeChunkerTests: XCTestCase {
    func testEmptyStringProducesNoChunks() {
        XCTAssertTrue(UnicodeChunker.chunks(of: "").isEmpty)
    }

    func testShortStringStaysWhole() {
        XCTAssertEqual(UnicodeChunker.chunks(of: "hello", limit: 20), ["hello"])
    }

    func testSplitsOnTheLimit() {
        XCTAssertEqual(
            UnicodeChunker.chunks(of: "abcdefghij", limit: 4),
            ["abcd", "efgh", "ij"]
        )
    }

    func testExactMultipleOfTheLimit() {
        XCTAssertEqual(UnicodeChunker.chunks(of: "abcdefgh", limit: 4), ["abcd", "efgh"])
    }

    func testChunksAlwaysRejoinToTheOriginal() {
        let text = "Best,\nSouhaib 👋 — see you on 2026-08-02"
        for limit in 1...12 {
            XCTAssertEqual(UnicodeChunker.chunks(of: text, limit: limit).joined(), text)
        }
    }

    func testSurrogatePairsAreNeverSplit() {
        // Each emoji is two UTF-16 units; a naive split at 3 would break one.
        let chunks = UnicodeChunker.chunks(of: "👋🌍🎉", limit: 3)
        XCTAssertEqual(chunks, ["👋", "🌍", "🎉"])
        XCTAssertEqual(chunks.joined(), "👋🌍🎉")
    }

    func testCharacterLongerThanTheLimitGoesOutAlone() {
        // A family emoji is one Character but many UTF-16 units.
        let family = "👨‍👩‍👧‍👦"
        XCTAssertTrue(family.utf16.count > 4)
        XCTAssertEqual(UnicodeChunker.chunks(of: "ab\(family)cd", limit: 4), ["ab", family, "cd"])
    }

    func testNoChunkExceedsTheLimitUnlessASingleCharacterDoes() {
        let text = "abcdef👋ghij🌍klmno"
        for chunk in UnicodeChunker.chunks(of: text, limit: 5) {
            XCTAssertTrue(chunk.utf16.count <= 5 || chunk.count == 1)
        }
    }

    func testNonPositiveLimitReturnsTheWholeString() {
        XCTAssertEqual(UnicodeChunker.chunks(of: "hello", limit: 0), ["hello"])
        XCTAssertEqual(UnicodeChunker.chunks(of: "hello", limit: -1), ["hello"])
    }

    func testNewlinesSurvive() {
        XCTAssertEqual(UnicodeChunker.chunks(of: "a\nb", limit: 20).joined(), "a\nb")
    }
}
