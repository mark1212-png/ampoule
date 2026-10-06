import AmpouleCore
import Foundation
import Virtualization

public enum VZBackendError: Error, Equatable, CustomStringConvertible {
    case unsupportedGuest(GuestOS)
    case unreadableState(String)
    case installMediaNotFound(String)
    case installMediaNotSupported(GuestOS)
    case macOSNotInstalled
    case unsupportedHardwareModel
    case restoreImageNotFound(String)
    case restoreImageUnsupported
    case belowMinimumCPUCount(have: Int, need: Int)
    case belowMinimumMemory(haveMiB: Int, needMiB: Int)

    public var description: String {
        switch self {
        case .unsupportedGuest(let guestOS):
            "The Virtualization.framework backend can't run \(guestOS.rawValue) guests."
        case .unreadableState(let fileName):
            "The bundle's \(fileName) is damaged. Refusing to replace it, because the guest would see new hardware."
        case .installMediaNotFound(let path):
            "Install media \"\(path)\" doesn't exist or isn't a file."
        case .installMediaNotSupported(let guestOS):
            "\(guestOS.rawValue) guests can't boot from install media; they're installed from a restore image when created."
        case .macOSNotInstalled:
            "This macOS VM has no installed system (vz.json is missing). Create it again with --ipsw."
        case .unsupportedHardwareModel:
            "This Mac can't run the macOS version installed in this VM."
        case .restoreImageNotFound(let path):
            "Restore image \"\(path)\" doesn't exist or isn't a file."
        case .restoreImageUnsupported:
            "This Mac can't virtualize the macOS version in this restore image."
        case .belowMinimumCPUCount(let have, let need):
            "This macOS version needs at least \(need) CPUs; the VM has \(have)."
        case .belowMinimumMemory(let haveMiB, let needMiB):
            "This macOS version needs at least \(needMiB) MiB of memory; the VM has \(haveMiB)."
        }
    }
}

/// Translates an Ampoule bundle into a Virtualization.framework configuration.
public enum VZConfigurationBuilder {
    public static let efiVariableStoreFileName = "efi-variables.bin"
    public static let auxiliaryStorageFileName = "auxiliary-storage.bin"
    public static let displayWidth = 1920
    public static let displayHeight = 1200
    public static let macDisplayPixelsPerInch = 144

    /// Builds and validates the configuration. `installMedia` (an ISO, Linux only) is attached read-only as a USB drive for this run only.
    ///
    /// Validation needs the `com.apple.security.virtualization` entitlement, so only signed binaries can call this.
    public static func makeConfiguration(for bundle: VMBundle, installMedia: URL? = nil) throws -> VZVirtualMachineConfiguration {
        let configuration = try buildConfiguration(for: bundle, installMedia: installMedia)
        try configuration.validate()
        return configuration
    }

    /// Builds the configuration without validating it. Separate so unit tests can run without the entitlement.
    static func buildConfiguration(for bundle: VMBundle, installMedia: URL?) throws -> VZVirtualMachineConfiguration {
        let guestOS = bundle.configuration.guestOS
        switch guestOS {
        case .linux:
            return try buildLinuxConfiguration(for: bundle, installMedia: installMedia)
        case .macOS:
            guard installMedia == nil else {
                throw VZBackendError.installMediaNotSupported(guestOS)
            }
            return try buildMacConfiguration(for: bundle)
        case .windows:
            throw VZBackendError.unsupportedGuest(guestOS)
        }
    }

    private static func buildLinuxConfiguration(for bundle: VMBundle, installMedia: URL?) throws -> VZVirtualMachineConfiguration {
        let state = try VZBackendState.loadOrCreateLinux(in: bundle)
        let configuration = try makeCommonConfiguration(for: bundle, state: state)

        let platform = VZGenericPlatformConfiguration()
        // Force-unwrap is safe: VZBackendState checked the value parses.
        platform.machineIdentifier = VZGenericMachineIdentifier(dataRepresentation: state.machineIdentifier)!
        configuration.platform = platform

        let bootLoader = VZEFIBootLoader()
        bootLoader.variableStore = try efiVariableStore(in: bundle)
        configuration.bootLoader = bootLoader

        if let installMedia {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: installMedia.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                throw VZBackendError.installMediaNotFound(installMedia.path)
            }
            configuration.storageDevices.append(VZUSBMassStorageDeviceConfiguration(
                attachment: try VZDiskImageStorageDeviceAttachment(url: installMedia, readOnly: true)
            ))
        }

        let graphics = VZVirtioGraphicsDeviceConfiguration()
        graphics.scanouts = [VZVirtioGraphicsScanoutConfiguration(widthInPixels: displayWidth, heightInPixels: displayHeight)]
        configuration.graphicsDevices = [graphics]
        configuration.keyboards = [VZUSBKeyboardConfiguration()]
        configuration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        return configuration
    }

    private static func buildMacConfiguration(for bundle: VMBundle) throws -> VZVirtualMachineConfiguration {
        guard let state = try VZBackendState.load(from: bundle), let hardwareModelData = state.hardwareModel else {
            throw VZBackendError.macOSNotInstalled
        }
        // Force-unwraps are safe: VZBackendState checked both values parse.
        let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData)!
        guard hardwareModel.isSupported else {
            throw VZBackendError.unsupportedHardwareModel
        }
        let auxiliaryStorageURL = bundle.url.appending(path: auxiliaryStorageFileName)
        guard FileManager.default.fileExists(atPath: auxiliaryStorageURL.path) else {
            throw VZBackendError.macOSNotInstalled
        }

        let configuration = try makeCommonConfiguration(for: bundle, state: state)

        let platform = VZMacPlatformConfiguration()
        platform.hardwareModel = hardwareModel
        platform.machineIdentifier = VZMacMachineIdentifier(dataRepresentation: state.machineIdentifier)!
        platform.auxiliaryStorage = VZMacAuxiliaryStorage(url: auxiliaryStorageURL)
        configuration.platform = platform
        configuration.bootLoader = VZMacOSBootLoader()

        let graphics = VZMacGraphicsDeviceConfiguration()
        graphics.displays = [VZMacGraphicsDisplayConfiguration(
            widthInPixels: displayWidth,
            heightInPixels: displayHeight,
            pixelsPerInch: macDisplayPixelsPerInch
        )]
        configuration.graphicsDevices = [graphics]
        configuration.keyboards = [VZMacKeyboardConfiguration()]
        configuration.pointingDevices = [VZMacTrackpadConfiguration(), VZUSBScreenCoordinatePointingDeviceConfiguration()]
        return configuration
    }

    /// CPU, memory, disks, network, entropy and memory balloon: the same for every guest.
    private static func makeCommonConfiguration(for bundle: VMBundle, state: VZBackendState) throws -> VZVirtualMachineConfiguration {
        let vmConfiguration = bundle.configuration
        let configuration = VZVirtualMachineConfiguration()
        configuration.cpuCount = vmConfiguration.cpuCount
        configuration.memorySize = UInt64(vmConfiguration.memoryMiB) << 20

        configuration.storageDevices = try vmConfiguration.disks.map { disk in
            VZVirtioBlockDeviceConfiguration(
                attachment: try VZDiskImageStorageDeviceAttachment(url: bundle.url(for: disk), readOnly: disk.readOnly)
            )
        }

        let network = VZVirtioNetworkDeviceConfiguration()
        network.attachment = VZNATNetworkDeviceAttachment()
        network.macAddress = VZMACAddress(string: state.macAddress)!
        configuration.networkDevices = [network]

        configuration.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
        configuration.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]
        return configuration
    }

    private static func efiVariableStore(in bundle: VMBundle) throws -> VZEFIVariableStore {
        let url = bundle.url.appending(path: efiVariableStoreFileName)
        if FileManager.default.fileExists(atPath: url.path) {
            return VZEFIVariableStore(url: url)
        }
        return try VZEFIVariableStore(creatingVariableStoreAt: url)
    }
}
