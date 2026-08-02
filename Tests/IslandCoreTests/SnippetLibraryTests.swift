import XCTest
@testable import IslandCore

final class SnippetLibraryTests: XCTestCase {
    private func library(_ labels: [String]) -> SnippetLibrary {
        SnippetLibrary(snippets: labels.map { Snippet(label: $0, content: $0) })
    }

    func testAppendAddsToTheEnd() {
        var library = self.library(["a", "b"])
        library.append(Snippet(label: "c", content: "c"))
        XCTAssertEqual(library.snippets.map(\.label), ["a", "b", "c"])
        XCTAssertEqual(library.count, 3)
    }

    func testAppendingAnExistingIdUpdatesInPlace() {
        var library = self.library(["a", "b"])
        var existing = library.snippets[0]
        existing.label = "renamed"
        library.append(existing)
        XCTAssertEqual(library.snippets.map(\.label), ["renamed", "b"])
    }

    func testUpdateReplacesTheMatchingSnippet() {
        var library = self.library(["a", "b"])
        var second = library.snippets[1]
        second.content = "changed"
        library.update(second)
        XCTAssertEqual(library.snippets[1].content, "changed")
    }

    func testUpdateIgnoresUnknownIds() {
        var library = self.library(["a"])
        library.update(Snippet(label: "ghost", content: "ghost"))
        XCTAssertEqual(library.snippets.map(\.label), ["a"])
    }

    func testRemove() {
        var library = self.library(["a", "b", "c"])
        library.remove(id: library.snippets[1].id)
        XCTAssertEqual(library.snippets.map(\.label), ["a", "c"])
    }

    func testRemovingAnUnknownIdIsANoOp() {
        var library = self.library(["a"])
        library.remove(id: UUID())
        XCTAssertEqual(library.count, 1)
    }

    func testSubscriptAndIndexLookup() {
        let library = self.library(["a", "b"])
        let id = library.snippets[1].id
        XCTAssertEqual(library[id]?.label, "b")
        XCTAssertEqual(library.index(of: id), 1)
        XCTAssertNil(library[UUID()])
        XCTAssertNil(library.index(of: UUID()))
    }

    func testMoveForwards() {
        var library = self.library(["a", "b", "c", "d"])
        library.move(from: 0, to: 2)
        XCTAssertEqual(library.snippets.map(\.label), ["b", "c", "a", "d"])
    }

    func testMoveBackwards() {
        var library = self.library(["a", "b", "c", "d"])
        library.move(from: 3, to: 1)
        XCTAssertEqual(library.snippets.map(\.label), ["a", "d", "b", "c"])
    }

    func testMoveToTheSamePlaceChangesNothing() {
        var library = self.library(["a", "b"])
        library.move(from: 1, to: 1)
        XCTAssertEqual(library.snippets.map(\.label), ["a", "b"])
    }

    func testMoveClampsOutOfRangeIndexes() {
        var library = self.library(["a", "b", "c"])
        library.move(from: 99, to: -4)
        XCTAssertEqual(library.snippets.map(\.label), ["c", "a", "b"])
    }

    func testMoveOnAnEmptyLibraryDoesNotTrap() {
        var library = SnippetLibrary()
        library.move(from: 0, to: 1)
        XCTAssertTrue(library.isEmpty)
    }

    func testStarterLibraryIsUsable() {
        let starter = SnippetLibrary.starter
        XCTAssertFalse(starter.isEmpty)
        XCTAssertTrue(starter.snippets.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(Set(starter.snippets.map(\.id)).count, starter.count, "ids must be unique")
    }

    func testCodableRoundTrip() throws {
        let library = self.library(["a", "b", "c"])
        let data = try JSONEncoder().encode(library)
        let decoded = try JSONDecoder().decode(SnippetLibrary.self, from: data)
        XCTAssertEqual(decoded, library)
    }
}
