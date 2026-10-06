import AmpouleCore
import Foundation
import Virtualization

/// Identity the guest must see on every boot, stored in `<bundle>/vz.json`.
///
/// Linux guests get one on first use. macOS guests get one when macOS is installed, because the
/// hardware model comes from the restore image. A file that exists but can't be read is an error
/// rather than regenerated: new values would make the guest see different hardware.
struct VZBackendState: Codable, Equatable {
    static let fileName = "vz.json"

    var machineIdentifier: Data
    var macAddress: String
    /// macOS guests only.
    var hardwareModel: Data?

    /// Reads and checks the state. Returns nil if the bundle has none yet.
    static func load(from bundle: VMBundle) throws -> VZBackendState? {
        let url = bundle.url.appending(path: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let state: VZBackendState
        do {
            state = try JSONDecoder().decode(VZBackendState.self, from: Data(contentsOf: url))
        } catch {
            throw VZBackendError.unreadableState(fileName)
        }
        guard state.isValid(for: bundle.configuration.guestOS) else {
            throw VZBackendError.unreadableState(fileName)
        }
        return state
    }

    static func loadOrCreateLinux(in bundle: VMBundle) throws -> VZBackendState {
        if let state = try load(from: bundle) {
            return state
        }
        let state = VZBackendState(
            machineIdentifier: VZGenericMachineIdentifier().dataRepresentation,
            macAddress: VZMACAddress.randomLocallyAdministered().string
        )
        try state.write(to: bundle)
        return state
    }

    static func newMac(hardwareModel: VZMacHardwareModel) -> VZBackendState {
        VZBackendState(
            machineIdentifier: VZMacMachineIdentifier().dataRepresentation,
            macAddress: VZMACAddress.randomLocallyAdministered().string,
            hardwareModel: hardwareModel.dataRepresentation
        )
    }

    /// Never overwrites an existing file.
    func write(to bundle: VMBundle) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: bundle.url.appending(path: Self.fileName), options: .withoutOverwriting)
    }

    private func isValid(for guestOS: GuestOS) -> Bool {
        guard VZMACAddress(string: macAddress) != nil else {
            return false
        }
        switch guestOS {
        case .linux:
            return VZGenericMachineIdentifier(dataRepresentation: machineIdentifier) != nil && hardwareModel == nil
        case .macOS:
            guard let hardwareModel, VZMacHardwareModel(dataRepresentation: hardwareModel) != nil else {
                return false
            }
            return VZMacMachineIdentifier(dataRepresentation: machineIdentifier) != nil
        case .windows:
            return false
        }
    }
}
