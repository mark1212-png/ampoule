import AmpouleCore
@testable import AmpouleAppModel
import Foundation
import Testing

@MainActor
private func makeModel() throws -> (LibraryModel, URL) {
    let directory = FileManager.default.temporaryDirectory.appending(path: "AmpouleModelTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return (LibraryModel(library: VMLibrary(directory: directory)), directory)
}

@MainActor
private func validBundles(_ model: LibraryModel) -> [VMBundle] {
    model.entries.compactMap { entry in
        if case .valid(let bundle) = entry { bundle } else { nil }
    }
}

@MainActor
@Suite struct LibraryModelTests {
    @Test func reloadListsValidAndBrokenBundles() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        _ = try model.create(name: "Ubuntu", guestOS: .linux, cpuCount: 2, memoryMiB: 2048, diskSizeGiB: 8)
        try FileManager.default.createDirectory(at: directory.appending(path: "Broken.ampoule"), withIntermediateDirectories: false)
        model.reload()

        #expect(model.entries.count == 2)
        #expect(validBundles(model).map(\.configuration.name) == ["Ubuntu"])
    }

    @Test func createRefusesDuplicateNames() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        _ = try model.create(name: "Ubuntu", guestOS: .linux, cpuCount: 2, memoryMiB: 2048, diskSizeGiB: 8)
        #expect(throws: BundleError.alreadyExists("Ubuntu")) {
            try model.create(name: "Ubuntu", guestOS: .linux, cpuCount: 2, memoryMiB: 2048, diskSizeGiB: 8)
        }
    }

    @Test func macOSInstallRefusesBadAndTakenNamesBeforeStarting() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = try model.create(name: "Taken", guestOS: .linux, cpuCount: 2, memoryMiB: 2048, diskSizeGiB: 8)
        let source = LibraryModel.RestoreImageSource.file(URL(filePath: "/nonexistent.ipsw"))

        #expect(throws: BundleError.invalidName("a/b")) {
            try model.createMacOS(name: "a/b", cpuCount: 4, memoryMiB: 8192, diskSizeGiB: 64, source: source)
        }
        #expect(throws: BundleError.alreadyExists("Taken")) {
            try model.createMacOS(name: "Taken", cpuCount: 4, memoryMiB: 8192, diskSizeGiB: 64, source: source)
        }
        #expect(model.installations.isEmpty)
    }

    @Test func macOSInstallRefusesANameAlreadyInstalling() async throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = LibraryModel.RestoreImageSource.file(URL(filePath: "/nonexistent.ipsw"))

        try model.createMacOS(name: "Mac", cpuCount: 4, memoryMiB: 8192, diskSizeGiB: 64, source: source)
        #expect(throws: BundleError.alreadyExists("Mac")) {
            try model.createMacOS(name: "Mac", cpuCount: 4, memoryMiB: 8192, diskSizeGiB: 64, source: source)
        }
        await model.installations.first?.task?.value
    }

    @Test func failedInstallReportsErrorAndLeavesNothingBehind() async throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        var becameIdle = false
        model.onAllStopped = { becameIdle = true }

        try model.createMacOS(name: "Mac", cpuCount: 4, memoryMiB: 8192, diskSizeGiB: 64, source: .file(URL(filePath: "/nonexistent.ipsw")))
        #expect(!model.isIdle)
        await model.installations.first?.task?.value

        #expect(model.installations.isEmpty)
        #expect(model.errorMessage?.contains("/nonexistent.ipsw") == true)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        #expect(becameIdle)
    }

    @Test func cancelledInstallReportsNoError() async throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        try model.createMacOS(name: "Mac", cpuCount: 4, memoryMiB: 8192, diskSizeGiB: 64, source: .file(URL(filePath: "/nonexistent.ipsw")))
        let installation = try #require(model.installations.first)
        installation.cancel()
        await installation.task?.value

        #expect(model.installations.isEmpty)
        #expect(model.errorMessage == nil)
    }

    @Test func sharedFoldersSaveWhenStoppedAndAreRefusedWhileRunning() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let bundle = try model.create(name: "Ubuntu", guestOS: .linux, cpuCount: 2, memoryMiB: 2048, diskSizeGiB: 8)
        let folder = SharedFolder(path: directory.path)

        do {
            let lock = try BundleLock(bundle: bundle)
            model.setSharedFolders([folder], for: bundle)
            #expect(model.errorMessage == BundleError.alreadyRunning("Ubuntu").description)
            #expect(validBundles(model).first?.configuration.sharedFolders.isEmpty == true)
            withExtendedLifetime(lock) {}
        }

        model.errorMessage = nil
        model.setSharedFolders([folder], for: bundle)
        #expect(model.errorMessage == nil)
        #expect(validBundles(model).first?.configuration.sharedFolders == [folder])
    }

    @Test func failedStartReportsErrorAndReleasesTheLock() throws {
        let (model, directory) = try makeModel()
        defer { try? FileManager.default.removeItem(at: directory) }
        let bundle = try model.create(name: "Win", guestOS: .windows, cpuCount: 2, memoryMiB: 4096, diskSizeGiB: 8)

        #expect(!model.start(bundle))
        #expect(model.errorMessage != nil)
        #expect(model.running.isEmpty)
        _ = try BundleLock(bundle: bundle)
    }
}
