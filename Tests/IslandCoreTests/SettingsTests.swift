import XCTest
@testable import IslandCore

final class SettingsTests: XCTestCase {
    func testDefaults() {
        let settings = Settings()
        XCTAssertEqual(settings.insertMethod, .paste)
        XCTAssertTrue(settings.expandPlaceholders)
        XCTAssertTrue(settings.spaceBeforeInsert)
        XCTAssertTrue(settings.isIslandVisible)
        XCTAssertFalse(settings.isCollapsed)
        XCTAssertNil(settings.panelOrigin)
    }

    func testCodableRoundTrip() throws {
        var settings = Settings(insertMethod: .type, expandPlaceholders: false, isCollapsed: true)
        settings.panelOrigin = CGPoint(x: 120, y: 640)

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)

        XCTAssertEqual(decoded, settings)
        XCTAssertEqual(decoded.panelOrigin, CGPoint(x: 120, y: 640))
    }

    func testDecodingAnEmptyObjectGivesDefaults() throws {
        let decoded = try JSONDecoder().decode(Settings.self, from: Data("{}".utf8))
        XCTAssertEqual(decoded, Settings())
    }

    func testMissingKeysFallBackIndividually() throws {
        // A settings file written by an older build only knows some of the keys.
        let json = Data(#"{"insertMethod":"type"}"#.utf8)
        let decoded = try JSONDecoder().decode(Settings.self, from: json)
        XCTAssertEqual(decoded.insertMethod, .type)
        XCTAssertTrue(decoded.expandPlaceholders)
        XCTAssertTrue(decoded.isIslandVisible)
        XCTAssertTrue(decoded.spaceBeforeInsert, "a file written before this setting existed keeps the default")
    }

    func testSpaceBeforeInsertSurvivesEncoding() throws {
        let settings = Settings(spaceBeforeInsert: false)
        let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
        XCTAssertFalse(decoded.spaceBeforeInsert)
    }

    func testUnknownInsertMethodIsARealDecodingError() {
        let json = Data(#"{"insertMethod":"telepathy"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(Settings.self, from: json))
    }

    func testHalfAPositionCountsAsNoPosition() throws {
        let json = Data(#"{"panelOriginX":40}"#.utf8)
        let decoded = try JSONDecoder().decode(Settings.self, from: json)
        XCTAssertNil(decoded.panelOrigin)
    }

    func testClearingThePositionClearsBothCoordinates() {
        var settings = Settings()
        settings.panelOrigin = CGPoint(x: 10, y: 20)
        settings.panelOrigin = nil
        XCTAssertNil(settings.panelOriginX)
        XCTAssertNil(settings.panelOriginY)
    }

    func testInsertMethodsHaveTitles() {
        for method in InsertMethod.allCases {
            XCTAssertFalse(method.title.isEmpty)
        }
    }
}
