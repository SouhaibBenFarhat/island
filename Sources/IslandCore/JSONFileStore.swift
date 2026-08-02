import Foundation

/// Reads and writes one Codable value as a JSON file.
///
/// Loading never throws: a missing, unreadable or corrupt file falls back to
/// `fallback`. Losing a hand-edited snippets file should cost you your snippets,
/// not the ability to launch the app.
public struct JSONFileStore<Value: Codable & Sendable>: Sendable {
    public let url: URL
    public let fallback: Value

    public init(url: URL, fallback: Value) {
        self.url = url
        self.fallback = fallback
    }

    public func load() -> Value {
        guard let data = try? Data(contentsOf: url) else { return fallback }
        guard let value = try? Self.decoder.decode(Value.self, from: data) else { return fallback }
        return value
    }

    public func save(_ value: Value) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(value)
        // Atomic, so a crash mid-write can't leave a half-file behind.
        try data.write(to: url, options: .atomic)
    }

    private static var decoder: JSONDecoder { JSONDecoder() }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

/// Where Island keeps its files: `~/Library/Application Support/Island/`.
public enum StorageLocation {
    public static let directoryName = "Island"

    public static func applicationSupportDirectory(
        fileManager: FileManager = .default
    ) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent(directoryName, isDirectory: true)
    }

    public static func snippetsURL(in directory: URL) -> URL {
        directory.appendingPathComponent("snippets.json")
    }

    public static func settingsURL(in directory: URL) -> URL {
        directory.appendingPathComponent("settings.json")
    }
}
