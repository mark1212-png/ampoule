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
