import AmpouleCore
import Foundation
import Virtualization

/// Installs macOS into a new bundle from a restore image (`.ipsw`).
@MainActor
public enum MacOSInstallation {
    /// The newest macOS restore image this Mac can virtualize, as listed by Apple.
    public static func latestRestoreImage() async throws -> (url: URL, version: String) {
        let image = try await VZMacOSRestoreImage.latestSupported
        let version = image.operatingSystemVersion
        return (image.url, "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion) (\(image.buildVersion))")
    }

    /// Installs macOS into `bundle`, which must be freshly staged (no `vz.json` yet).
    ///
    /// `progress` receives the fraction completed (0–1) on an arbitrary thread.
    /// Cancelling the task cancels the installation.
    public static func install(
        into bundle: VMBundle,
        restoreImage: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: restoreImage.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw VZBackendError.restoreImageNotFound(restoreImage.path)
        }
        let image = try await VZMacOSRestoreImage.image(from: restoreImage)
        guard let requirements = image.mostFeaturefulSupportedConfiguration, requirements.hardwareModel.isSupported else {
            throw VZBackendError.restoreImageUnsupported
        }
        try checkRequirements(
            cpuCount: bundle.configuration.cpuCount,
            memoryMiB: bundle.configuration.memoryMiB,
            minimumCPUCount: requirements.minimumSupportedCPUCount,
            minimumMemoryBytes: requirements.minimumSupportedMemorySize
        )

        _ = try VZMacAuxiliaryStorage(
            creatingStorageAt: bundle.url.appending(path: VZConfigurationBuilder.auxiliaryStorageFileName),
            hardwareModel: requirements.hardwareModel,
            options: []
        )
        try VZBackendState.newMac(hardwareModel: requirements.hardwareModel).write(to: bundle)

        let virtualMachine = VZVirtualMachine(configuration: try VZConfigurationBuilder.makeConfiguration(for: bundle))
        let installer = VZMacOSInstaller(virtualMachine: virtualMachine, restoringFromImageAt: restoreImage)
        let observation = installer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { installerProgress, _ in
            progress(installerProgress.fractionCompleted)
        }
        defer { observation.invalidate() }
        try await withTaskCancellationHandler {
            try await installer.install()
        } onCancel: {
            installer.progress.cancel()
        }
    }

    nonisolated static func checkRequirements(
        cpuCount: Int,
        memoryMiB: Int,
        minimumCPUCount: Int,
        minimumMemoryBytes: UInt64
    ) throws(VZBackendError) {
        guard cpuCount >= minimumCPUCount else {
            throw .belowMinimumCPUCount(have: cpuCount, need: minimumCPUCount)
        }
        let minimumMemoryMiB = Int((minimumMemoryBytes + (1 << 20) - 1) >> 20)
        guard memoryMiB >= minimumMemoryMiB else {
            throw .belowMinimumMemory(haveMiB: memoryMiB, needMiB: minimumMemoryMiB)
        }
    }
}
