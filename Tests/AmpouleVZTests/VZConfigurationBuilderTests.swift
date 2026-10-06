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

@Test(arguments: [GuestOS.macOS, .windows])
func nonLinuxGuestsAreRejected(guestOS: GuestOS) throws {
    let (bundle, cleanup) = try makeBundle(guestOS: guestOS)
    defer { cleanup() }

    #expect(throws: VZBackendError.unsupportedGuest(guestOS)) {
        try VZConfigurationBuilder.buildConfiguration(for: bundle, installMedia: nil)
    }
    #expect(!VZBackend().supports(guestOS))
}
