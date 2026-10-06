import AmpouleCore
@testable import AmpouleVZ
import Foundation
import Testing
import Virtualization

private func makeBundle(guestOS: GuestOS = .linux) throws -> (VMBundle, cleanup: () -> Void) {
    let directory = FileManager.default.temporaryDirectory.appending(path: "AmpouleVZTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    let bundle = try VMBundle.create(in: directory, name: "Test", guestOS: guestOS, cpuCount: 2, memoryMiB: 2048, diskSizeGiB: 1)
    return (bundle, { try? FileManager.default.removeItem(at: directory) })
}

@Test func linuxConfigurationHasExpectedDevices() throws {
    let (bundle, cleanup) = try makeBundle()
    defer { cleanup() }

    let configuration = try VZConfigurationBuilder.buildConfiguration(for: bundle, installMedia: nil)

    #expect(configuration.cpuCount == 2)
    #expect(configuration.memorySize == 2048 << 20)
    #expect(configuration.storageDevices.count == 1)
    #expect(configuration.bootLoader is VZEFIBootLoader)
    #expect(configuration.networkDevices.first?.attachment is VZNATNetworkDeviceAttachment)
    #expect(configuration.graphicsDevices.count == 1)
}

@Test func firstBuildCreatesBackendFiles() throws {
    let (bundle, cleanup) = try makeBundle()
    defer { cleanup() }

    _ = try VZConfigurationBuilder.buildConfiguration(for: bundle, installMedia: nil)

    #expect(FileManager.default.fileExists(atPath: bundle.url.appending(path: VZBackendState.fileName).path))
    #expect(FileManager.default.fileExists(atPath: bundle.url.appending(path: VZConfigurationBuilder.efiVariableStoreFileName).path))
}

@Test func machineIdentityIsStableAcrossBuilds() throws {
    let (bundle, cleanup) = try makeBundle()
    defer { cleanup() }

    let first = try VZConfigurationBuilder.buildConfiguration(for: bundle, installMedia: nil)
    let second = try VZConfigurationBuilder.buildConfiguration(for: bundle, installMedia: nil)

    let firstPlatform = try #require(first.platform as? VZGenericPlatformConfiguration)
    let secondPlatform = try #require(second.platform as? VZGenericPlatformConfiguration)
    #expect(firstPlatform.machineIdentifier.dataRepresentation == secondPlatform.machineIdentifier.dataRepresentation)
    #expect(first.networkDevices[0].macAddress.string == second.networkDevices[0].macAddress.string)
}

@Test func damagedStateIsAnErrorNotRegenerated() throws {
    let (bundle, cleanup) = try makeBundle()
    defer { cleanup() }

    let stateURL = bundle.url.appending(path: VZBackendState.fileName)
    try Data("not json".utf8).write(to: stateURL)

    #expect(throws: VZBackendError.unreadableState(VZBackendState.fileName)) {
        try VZConfigurationBuilder.buildConfiguration(for: bundle, installMedia: nil)
    }
    #expect(try Data(contentsOf: stateURL) == Data("not json".utf8))
}

@Test func installMediaIsAttachedAsUSBDrive() throws {
    let (bundle, cleanup) = try makeBundle()
    defer { cleanup() }

    let iso = bundle.url.appending(path: "installer.iso")
    try Data(count: 1 << 20).write(to: iso)

    let configuration = try VZConfigurationBuilder.buildConfiguration(for: bundle, installMedia: iso)

    #expect(configuration.storageDevices.count == 2)
    #expect(configuration.storageDevices[1] is VZUSBMassStorageDeviceConfiguration)
}

@Test func missingInstallMediaIsAnError() throws {
    let (bundle, cleanup) = try makeBundle()
    defer { cleanup() }

    let missing = URL(filePath: "/nonexistent/installer.iso")
    #expect(throws: VZBackendError.installMediaNotFound(missing.path)) {
        try VZConfigurationBuilder.buildConfiguration(for: bundle, installMedia: missing)
    }
}

@Test func windowsIsRejected() throws {
    let (bundle, cleanup) = try makeBundle(guestOS: .windows)
    defer { cleanup() }

    #expect(throws: VZBackendError.unsupportedGuest(.windows)) {
        try VZConfigurationBuilder.buildConfiguration(for: bundle, installMedia: nil)
    }
    #expect(!VZBackend().supports(.windows))
    #expect(VZBackend().supports(.macOS))
    #expect(VZBackend().supports(.linux))
}

@Test func macOSBundleWithoutInstallIsAnError() throws {
    let (bundle, cleanup) = try makeBundle(guestOS: .macOS)
    defer { cleanup() }

    #expect(throws: VZBackendError.macOSNotInstalled) {
        try VZConfigurationBuilder.buildConfiguration(for: bundle, installMedia: nil)
    }
    // Unlike Linux, a macOS bundle never gets identity files invented for it.
    #expect(!FileManager.default.fileExists(atPath: bundle.url.appending(path: VZBackendState.fileName).path))
}

@Test func macOSRejectsInstallMedia() throws {
    let (bundle, cleanup) = try makeBundle(guestOS: .macOS)
    defer { cleanup() }

    #expect(throws: VZBackendError.installMediaNotSupported(.macOS)) {
        try VZConfigurationBuilder.buildConfiguration(for: bundle, installMedia: URL(filePath: "/tmp/installer.iso"))
    }
}

@Test func linuxStateIsRejectedForMacOSBundle() throws {
    let (linux, cleanupLinux) = try makeBundle(guestOS: .linux)
    defer { cleanupLinux() }
    let (mac, cleanupMac) = try makeBundle(guestOS: .macOS)
    defer { cleanupMac() }

    _ = try VZConfigurationBuilder.buildConfiguration(for: linux, installMedia: nil)
    try FileManager.default.copyItem(
        at: linux.url.appending(path: VZBackendState.fileName),
        to: mac.url.appending(path: VZBackendState.fileName)
    )

    #expect(throws: VZBackendError.unreadableState(VZBackendState.fileName)) {
        try VZConfigurationBuilder.buildConfiguration(for: mac, installMedia: nil)
    }
}

@Test func installRefusesMissingRestoreImage() async throws {
    let (bundle, cleanup) = try makeBundle(guestOS: .macOS)
    defer { cleanup() }

    let missing = URL(filePath: "/nonexistent/macOS.ipsw")
    await #expect(throws: VZBackendError.restoreImageNotFound(missing.path)) {
        try await MacOSInstallation.install(into: bundle, restoreImage: missing) { _ in }
    }
}

@Test func requirementsCheckCPUAndMemory() throws {
    try MacOSInstallation.checkRequirements(cpuCount: 2, memoryMiB: 4096, minimumCPUCount: 2, minimumMemoryBytes: 4 << 30)
    #expect(throws: VZBackendError.belowMinimumCPUCount(have: 1, need: 2)) {
        try MacOSInstallation.checkRequirements(cpuCount: 1, memoryMiB: 4096, minimumCPUCount: 2, minimumMemoryBytes: 4 << 30)
    }
    #expect(throws: VZBackendError.belowMinimumMemory(haveMiB: 2048, needMiB: 4096)) {
        try MacOSInstallation.checkRequirements(cpuCount: 2, memoryMiB: 2048, minimumCPUCount: 2, minimumMemoryBytes: 4 << 30)
    }
    // A minimum that isn't a whole number of MiB rounds up, never down.
    #expect(throws: VZBackendError.belowMinimumMemory(haveMiB: 4096, needMiB: 4097)) {
        try MacOSInstallation.checkRequirements(cpuCount: 2, memoryMiB: 4096, minimumCPUCount: 2, minimumMemoryBytes: (4 << 30) + 1)
    }
}

@Test func cachedRestoreImageIsReusedWithoutDownloading() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "AmpouleCache-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let cached = directory.appending(path: "UniversalMac_Restore.ipsw")
    try Data("cached".utf8).write(to: cached)

    // The host doesn't resolve, so this only passes if no download is attempted.
    let remote = URL(string: "https://ampoule.invalid/UniversalMac_Restore.ipsw")!
    let result = try await RestoreImageCache.localCopy(of: remote, in: directory) { _, _ in }

    #expect(result == cached)
}

@Test func failedDownloadLeavesNothingBehind() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "AmpouleCache-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: directory) }

    let remote = URL(string: "https://ampoule.invalid/UniversalMac_Restore.ipsw")!
    await #expect(throws: (any Error).self) {
        try await RestoreImageCache.localCopy(of: remote, in: directory) { _, _ in }
    }
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
}
