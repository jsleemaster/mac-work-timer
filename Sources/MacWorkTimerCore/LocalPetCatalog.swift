import Foundation

public struct LocalPetDescriptor: Equatable, Sendable {
    public let id: String
    public let stageImageURLs: [URL]

    public init(id: String, stageImageURLs: [URL]) {
        self.id = id
        self.stageImageURLs = stageImageURLs
    }
}

public struct LocalPetCatalog: Sendable {
    public static let legacyPetID = "local-evolution"
    public static let petIDPrefix = "local-"

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func descriptors() -> [LocalPetDescriptor] {
        var descriptors: [LocalPetDescriptor] = []

        let legacyStages = stageImageURLs(in: directory)
        if !legacyStages.isEmpty {
            descriptors.append(LocalPetDescriptor(id: Self.legacyPetID, stageImageURLs: legacyStages))
        }

        let subdirectories = ((try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? [])
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        for subdirectory in subdirectories {
            let stages = stageImageURLs(in: subdirectory)
            guard !stages.isEmpty else {
                continue
            }

            descriptors.append(LocalPetDescriptor(
                id: "\(Self.petIDPrefix)\(Self.sanitizedIDComponent(subdirectory.lastPathComponent))",
                stageImageURLs: stages
            ))
        }

        return descriptors
    }

    public func descriptor(for id: String) -> LocalPetDescriptor? {
        descriptors().first { $0.id == id }
    }

    public static func sanitizedIDComponent(_ value: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-_")
        let lowered = value.lowercased()
        let characters = lowered.map { character -> Character in
            allowed.contains(character) ? character : "-"
        }
        let sanitized = String(characters)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")

        return sanitized.isEmpty ? "pet" : sanitized
    }

    private func stageImageURLs(in directory: URL) -> [URL] {
        let urls = ((try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? [])

        return urls.compactMap { url -> (Int, URL)? in
            guard url.pathExtension.lowercased() == "png",
                  let number = Self.stageNumber(from: url.lastPathComponent) else {
                return nil
            }

            return (number, url)
        }
        .sorted { lhs, rhs in lhs.0 < rhs.0 }
        .map(\.1)
    }

    private static func stageNumber(from fileName: String) -> Int? {
        guard fileName.hasPrefix("stage-"), fileName.hasSuffix(".png") else {
            return nil
        }

        let start = fileName.index(fileName.startIndex, offsetBy: "stage-".count)
        let end = fileName.index(fileName.endIndex, offsetBy: -".png".count)
        return Int(fileName[start..<end])
    }
}
