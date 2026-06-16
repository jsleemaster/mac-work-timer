import XCTest
@testable import MacWorkTimerCore

final class LocalPetCatalogTests: XCTestCase {
    func testSubdirectoryStagesBecomeOneLocalPet() throws {
        let directory = try temporaryDirectory()
        let petDirectory = directory.appendingPathComponent("kakao-meme", isDirectory: true)
        try FileManager.default.createDirectory(at: petDirectory, withIntermediateDirectories: true)
        try writeEmptyFile(petDirectory.appendingPathComponent("stage-0.png"))
        try writeEmptyFile(petDirectory.appendingPathComponent("stage-1.png"))
        try writeEmptyFile(petDirectory.appendingPathComponent("stage-2.png"))
        try writeEmptyFile(petDirectory.appendingPathComponent("stage-3.png"))

        let catalog = LocalPetCatalog(directory: directory)
        let pets = catalog.descriptors()

        XCTAssertEqual(pets.map(\.id), ["local-kakao-meme"])
        XCTAssertEqual(pets.first?.stageImageURLs.map(\.lastPathComponent), [
            "stage-0.png",
            "stage-1.png",
            "stage-2.png",
            "stage-3.png"
        ])
    }

    func testRootStagesPreserveLegacyLocalEvolutionPet() throws {
        let directory = try temporaryDirectory()
        try writeEmptyFile(directory.appendingPathComponent("stage-1.png"))
        try writeEmptyFile(directory.appendingPathComponent("stage-3.png"))
        try writeEmptyFile(directory.appendingPathComponent("README.md"))

        let catalog = LocalPetCatalog(directory: directory)
        let pets = catalog.descriptors()

        XCTAssertEqual(pets.map(\.id), [LocalPetCatalog.legacyPetID])
        XCTAssertEqual(pets.first?.stageImageURLs.map(\.lastPathComponent), [
            "stage-1.png",
            "stage-3.png"
        ])
    }

    func testDirectoriesWithoutStageImagesAreIgnored() throws {
        let directory = try temporaryDirectory()
        let emptyPetDirectory = directory.appendingPathComponent("empty", isDirectory: true)
        try FileManager.default.createDirectory(at: emptyPetDirectory, withIntermediateDirectories: true)
        try writeEmptyFile(emptyPetDirectory.appendingPathComponent("note.txt"))

        let catalog = LocalPetCatalog(directory: directory)

        XCTAssertTrue(catalog.descriptors().isEmpty)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeEmptyFile(_ url: URL) throws {
        try Data().write(to: url)
    }
}
