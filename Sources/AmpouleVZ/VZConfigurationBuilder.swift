import AmpouleCore
import Foundation
import Virtualization

public enum VZBackendError: Error, Equatable, CustomStringConvertible {
    case unsupportedGuest(GuestOS)
    case unreadableState(String)
    case installMediaNotFound(String)

    public var description: String {
        switch self {
        case .unsupportedGuest(let guestOS):
            "The Virtualization.framework backend can't run \(guestOS.rawValue) guests yet."
        case .unreadableState(let fileName):
            "The bundle's \(fileName) is damaged. Refusing to replace it, because the guest would see new hardware."
        case .installMediaNotFound(let path):
            "Install media \"\(path)\" doesn't exist or isn't a file."
        }
    }
}

/// Translates an Ampoule bundle into a Virtualization.framework configuration.
public enum VZConfigurationBuilder {
    public static let efiVariableStoreFileName = "efi-variables.bin"
    public static let displayWidth = 1920
    public static let displayHeight = 1200

    /// Builds and validates the configuration. `installMedia` (an ISO) is attached read-only as a USB drive for this run only.
    ///
    /// Validation needs the `com.apple.security.virtualization` entitlement, so only signed binaries can call this.
    public static func makeConfiguration(for bundle: VMBundle, installMedia: URL? = nil) throws -> VZVirtualMachineConfiguration {
        let configuration = try buildConfiguration(for: bundle, installMedia: installMedia)
        try configuration.validate()
        return configuration
    }

    /// Builds the configuration without validating it. Separate so unit tests can run without the entitlement.
    static func buildConfiguration(for bundle: VMBundle, installMedia: URL?) throws -> VZVirtualMachineConfiguration {
        let vmConfiguration = bundle.configuration
        guard vmConfiguration.guestOS == .linux else {
            throw VZBackendError.unsupportedGuest(vmConfiguration.guestOS)
        }
        let state = try VZBackendState.loadOrCreate(in: bundle)

        let configuration = VZVirtualMachineConfiguration()
        configuration.cpuCount = vmConfiguration.cpuCount
        configuration.memorySize = UInt64(vmConfiguration.memoryMiB) << 20

        let platform = VZGenericPlatformConfiguration()
        // Force-unwraps are safe: loadOrCreate already checked both values parse.
        platform.machineIdentifier = VZGenericMachineIdentifier(dataRepresentation: state.machineIdentifier)!
        configuration.platform = platform

        let bootLoader = VZEFIBootLoader()
        bootLoader.variableStore = try efiVariableStore(in: bundle)
        configuration.bootLoader = bootLoader

        var storage: [VZStorageDeviceConfiguration] = try vmConfiguration.disks.map { disk in
            VZVirtioBlockDeviceConfiguration(
                attachment: try VZDiskImageStorageDeviceAttachment(url: bundle.url(for: disk), readOnly: disk.readOnly)
            )
        }
        if let installMedia {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: installMedia.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                throw VZBackendError.installMediaNotFound(installMedia.path)
            }
            storage.append(VZUSBMassStorageDeviceConfiguration(
                attachment: try VZDiskImageStorageDeviceAttachment(url: installMedia, readOnly: true)
            ))
        }
        configuration.storageDevices = storage

        let network = VZVirtioNetworkDeviceConfiguration()
        network.attachment = VZNATNetworkDeviceAttachment()
        network.macAddress = VZMACAddress(string: state.macAddress)!
        configuration.networkDevices = [network]

        let graphics = VZVirtioGraphicsDeviceConfiguration()
        graphics.scanouts = [VZVirtioGraphicsScanoutConfiguration(widthInPixels: displayWidth, heightInPixels: displayHeight)]
        configuration.graphicsDevices = [graphics]

        configuration.keyboards = [VZUSBKeyboardConfiguration()]
        configuration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
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
