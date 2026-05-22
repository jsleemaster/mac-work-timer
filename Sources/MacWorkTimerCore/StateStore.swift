import Foundation

public final class StateStore {
    public let directory: URL
    public let fileURL: URL

    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent("state.json")
        self.fileManager = fileManager

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    public static var `default`: StateStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return StateStore(directory: base.appendingPathComponent("Mac Work Timer", isDirectory: true))
    }

    public func load() throws -> AppState {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .empty
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(AppState.self, from: data)
        } catch {
            return .empty
        }
    }

    public func save(_ state: AppState) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }
}
