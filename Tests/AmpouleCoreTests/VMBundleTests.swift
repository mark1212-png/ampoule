@testable import AmpouleCore
import Foundation
import Testing

/// A fresh, empty directory for one test.
private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "AmpouleTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func createUbuntu(in directory: URL, diskSizeGiB: Int = 8) throws -> VMBundle {
    try VMBundle.create(in: directory, name: "Ubuntu", guestOS: .linux, cpuCount: 2, memoryMiB: 2048, diskSizeGiB: diskSizeGiB)
}

@Test func createThenOpenRoundTrips() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let created = try createUbuntu(in: directory)
    let opened = try VMBundle.open(at: created.url)

    #expect(opened.configuration == created.configuration)
    #expect(created.url.lastPathComponent == "Ubuntu.ampoule")
}

@Test func diskIsSparseWithRequestedSize() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let bundle = try createUbuntu(in: directory, diskSizeGiB: 8)
    let values = try bundle.url(for: bundle.configuration.disks[0])
        .resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])

    #expect(values.fileSize == 8 << 30)
    #expect((values.totalFileAllocatedSize ?? .max) < 1 << 20)
}

@Test func refusesToOverwriteExistingBundle() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    _ = try createUbuntu(in: directory)
    #expect(throws: BundleError.alreadyExists("Ubuntu")) { try createUbuntu(in: directory) }
}

@Test(arguments: ["", ".hidden", "a/b", "a:b", " padded ", String(repeating: "x", count: 65)])
func rejectsInvalidNames(name: String) {
    #expect(throws: BundleError.invalidName(name)) { try VMBundle.validateName(name) }
}

@Test(arguments: [0, 2049])
func rejectsDiskSizeOutOfRange(size: Int) throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    #expect(throws: BundleError.diskSizeOutOfRange(size)) { try createUbuntu(in: directory, diskSizeGiB: size) }
}

@Test func failedCreateLeavesNothingBehind() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    #expect(throws: ConfigurationError.memoryTooSmall(1)) {
        try VMBundle.create(in: directory, name: "Tiny", guestOS: .linux, cpuCount: 1, memoryMiB: 1, diskSizeGiB: 8)
    }
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
}

@Test func openFailsWhenDiskIsMissing() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let bundle = try createUbuntu(in: directory)
    try FileManager.default.removeItem(at: bundle.url(for: bundle.configuration.disks[0]))

    #expect(throws: BundleError.missingDisk(VMBundle.primaryDiskFileName)) { try VMBundle.open(at: bundle.url) }
}

@Test func openFailsWithoutConfiguration() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let url = directory.appending(path: "Empty.ampoule", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)

    #expect(throws: BundleError.missingConfiguration("Empty.ampoule")) { try VMBundle.open(at: url) }
}

@Test func libraryReportsBrokenBundlesInsteadOfSkippingThem() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    _ = try createUbuntu(in: directory)
    try FileManager.default.createDirectory(at: directory.appending(path: "Broken.ampoule"), withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: directory.appending(path: "notes"), withIntermediateDirectories: false)

    let entries = try VMLibrary(directory: directory).entries()

    #expect(entries.count == 2)
    guard case .invalid(let url, _) = entries[0] else {
        Issue.record("Expected Broken.ampoule to be reported as invalid")
        return
    }
    #expect(url.lastPathComponent == "Broken.ampoule")
    guard case .valid(let bundle) = entries[1] else {
        Issue.record("Expected Ubuntu.ampoule to be valid")
        return
    }
    #expect(bundle.configuration.name == "Ubuntu")
}

@Test func missingLibraryDirectoryIsEmpty() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "AmpouleTests-missing-\(UUID().uuidString)")
    #expect(try VMLibrary(directory: directory).entries().isEmpty)
}

@Test func secondLockOnSameBundleFails() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let bundle = try createUbuntu(in: directory)
    let lock = try BundleLock(bundle: bundle)
    #expect(throws: BundleError.alreadyRunning("Ubuntu")) { try BundleLock(bundle: bundle) }
    withExtendedLifetime(lock) {}
}

@Test func lockIsReleasedWhenDropped() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let bundle = try createUbuntu(in: directory)
    do { _ = try BundleLock(bundle: bundle) }
    _ = try BundleLock(bundle: bundle)
}

@Test func libraryFindsBundleByName() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    _ = try createUbuntu(in: directory)
    let library = VMLibrary(directory: directory)

    #expect(try library.bundle(named: "Ubuntu").configuration.name == "Ubuntu")
    #expect(throws: BundleError.notFound("Debian")) { try library.bundle(named: "Debian") }
}

@MainActor
@Test func prepareStepRunsBeforeBundleAppears() async throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let bundle = try await VMBundle.create(in: directory, name: "Mac", guestOS: .macOS, cpuCount: 2, memoryMiB: 4096, diskSizeGiB: 8) { staged in
        #expect(staged.url.lastPathComponent.hasPrefix(".Mac."))
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "Mac.ampoule").path))
        try Data("installed".utf8).write(to: staged.url.appending(path: "marker"))
    }

    #expect(bundle.url.lastPathComponent == "Mac.ampoule")
    #expect(FileManager.default.fileExists(atPath: bundle.url.appending(path: "marker").path))
}

private struct InstallFailed: Error {}

@MainActor
@Test func failedPrepareLeavesNothingBehind() async throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    await #expect(throws: InstallFailed.self) {
        try await VMBundle.create(in: directory, name: "Mac", guestOS: .macOS, cpuCount: 2, memoryMiB: 4096, diskSizeGiB: 8) { _ in
            throw InstallFailed()
        }
    }
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
}

@MainActor
@Test func cancelledPrepareLeavesNothingBehind() async throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let task = Task { @MainActor in
        try await VMBundle.create(in: directory, name: "Mac", guestOS: .macOS, cpuCount: 2, memoryMiB: 4096, diskSizeGiB: 8) { _ in
            try await Task.sleep(for: .seconds(60))
        }
    }
    task.cancel()

    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
}

@Test func libraryKnowsWhichNamesAreTaken() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    _ = try createUbuntu(in: directory)
    try FileManager.default.createDirectory(at: directory.appending(path: "Broken.ampoule"), withIntermediateDirectories: false)
    let library = VMLibrary(directory: directory)

    #expect(library.containsBundle(named: "Ubuntu"))
    #expect(library.containsBundle(named: "Broken"))
    #expect(!library.containsBundle(named: "Debian"))
}
