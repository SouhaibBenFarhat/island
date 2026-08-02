import XCTest
@testable import IslandCore

final class SnippetColorTests: XCTestCase {
    func testHexUnpacksChannels() {
        let white = RGB(hex: 0xFFFFFF)
        XCTAssertEqual(white.red, 1, accuracy: 0.0001)
        XCTAssertEqual(white.green, 1, accuracy: 0.0001)
        XCTAssertEqual(white.blue, 1, accuracy: 0.0001)

        let black = RGB(hex: 0x000000)
        XCTAssertEqual(black, RGB(0, 0, 0))

        // 0xB4552E — the brand terracotta.
        let terracotta = RGB(hex: 0xB4552E)
        XCTAssertEqual(terracotta.red, 180.0 / 255, accuracy: 0.0001)
        XCTAssertEqual(terracotta.green, 85.0 / 255, accuracy: 0.0001)
        XCTAssertEqual(terracotta.blue, 46.0 / 255, accuracy: 0.0001)
    }

    func testEveryColourHasAName() {
        for color in SnippetColor.allCases {
            XCTAssertFalse(color.title.isEmpty)
        }
    }

    func testColoursAreAllDistinct() {
        let solids = SnippetColor.allCases.map(\.solid)
        XCTAssertEqual(Set(solids.map { "\($0)" }).count, solids.count)
    }

    func testLightVariantIsLighterThanTheSolidOne() {
        func luminance(_ rgb: RGB) -> Double {
            0.2126 * rgb.red + 0.7152 * rgb.green + 0.0722 * rgb.blue
        }
        for color in SnippetColor.allCases {
            XCTAssertGreaterThan(
                luminance(color.light), luminance(color.solid),
                "\(color.title)'s light variant should be lighter"
            )
        }
    }

    func testSolidColoursAreDarkEnoughToCarryWhiteText() {
        func luminance(_ rgb: RGB) -> Double {
            0.2126 * rgb.red + 0.7152 * rgb.green + 0.0722 * rgb.blue
        }
        for color in SnippetColor.allCases {
            XCTAssertLessThan(
                luminance(color.solid), 0.55,
                "\(color.title) is too light for white text on a petal"
            )
        }
    }

    func testRawValuesRoundTrip() {
        for color in SnippetColor.allCases {
            XCTAssertEqual(SnippetColor(rawValue: color.rawValue), color)
        }
    }

    func testPaletteIsBigEnoughToFillAFlower() {
        XCTAssertGreaterThanOrEqual(SnippetColor.allCases.count, RadialLayout.maximumPetals)
    }
}
