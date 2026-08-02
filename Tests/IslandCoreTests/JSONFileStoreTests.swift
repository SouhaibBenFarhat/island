import XCTest
@testable import IslandCore

final class JSONFileStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("island-tests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeStore() -> JSONFileStore<SnippetLibrary> {
        JSONFileStore(
            url: StorageLocation.snippetsURL(in: directory),
            fallback: SnippetLibrary.starter
        )
    }

    func testLoadingAMissingFileGivesTheFallback() {
        XCTAssertEqual(makeStore().load(), SnippetLibrary.starter)
    }

    func testSaveThenLoadRoundTrips() throws {
        let store = makeStore()
        let library = SnippetLibrary(snippets: [Snippet(label: "Email", content: "you@example.com")])
        try store.save(library)
        XCTAssertEqual(store.load(), library)
    }

    func testSaveCreatesMissingDirectories() throws {
        let nested = directory.appendingPathComponent("a/b/c")
        let store = JSONFileStore(url: nested.appendingPathComponent("x.json"), fallback: Settings())
        try store.save(Settings(insertMethod: .type))
        XCTAssertEqual(store.load().insertMethod, .type)
    }

    func testSavingTwiceOverwritesRatherThanAppends() throws {
        let store = makeStore()
        try store.save(SnippetLibrary(snippets: [Snippet(label: "one", content: "1")]))
        try store.save(SnippetLibrary(snippets: [Snippet(label: "two", content: "2")]))
        XCTAssertEqual(store.load().snippets.map(\.label), ["two"])
    }

    func testCorruptFileFallsBackInsteadOfCrashing() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("this is not json".utf8).write(to: StorageLocation.snippetsURL(in: directory))
        XCTAssertEqual(makeStore().load(), SnippetLibrary.starter)
    }

    func testValidJSONOfTheWrongShapeFallsBack() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"unexpected":true}"#.utf8).write(to: StorageLocation.snippetsURL(in: directory))
        XCTAssertEqual(makeStore().load(), SnippetLibrary.starter)
    }

    func testWrittenFileIsReadableJSON() throws {
        let store = makeStore()
        try store.save(SnippetLibrary(snippets: [Snippet(label: "Email", content: "you@example.com")]))
        let text = try String(contentsOf: store.url, encoding: .utf8)
        XCTAssertTrue(text.contains("\"label\""))
        XCTAssertTrue(text.contains("\n"), "should be pretty-printed so it can be hand-edited")
    }

    func testStorageLocationPaths() {
        let directory = StorageLocation.applicationSupportDirectory()
        XCTAssertEqual(directory.lastPathComponent, StorageLocation.directoryName)
        XCTAssertEqual(StorageLocation.snippetsURL(in: directory).lastPathComponent, "snippets.json")
        XCTAssertEqual(StorageLocation.settingsURL(in: directory).lastPathComponent, "settings.json")
    }

    func testSnippetsAndSettingsDoNotShareAFile() {
        let directory = StorageLocation.applicationSupportDirectory()
        XCTAssertNotEqual(
            StorageLocation.snippetsURL(in: directory),
            StorageLocation.settingsURL(in: directory)
        )
    }
}
