import AmpouleCore
import Foundation
import Virtualization

/// Identity the guest must see on every boot, stored in `<bundle>/vz.json`.
///
/// Created on first use. A file that exists but can't be read is an error rather than regenerated:
/// a new machine identifier or MAC address would make the guest see different hardware.
struct VZBackendState: Codable, Equatable {
    static let fileName = "vz.json"

    var machineIdentifier: Data
    var macAddress: String

    static func loadOrCreate(in bundle: VMBundle) throws -> VZBackendState {
        let url = bundle.url.appending(path: fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            let state: VZBackendState
            do {
                state = try JSONDecoder().decode(VZBackendState.self, from: Data(contentsOf: url))
            } catch {
                throw VZBackendError.unreadableState(fileName)
            }
            guard VZGenericMachineIdentifier(dataRepresentation: state.machineIdentifier) != nil,
                  VZMACAddress(string: state.macAddress) != nil
            else {
                throw VZBackendError.unreadableState(fileName)
            }
            return state
        }
        let state = VZBackendState(
            machineIdentifier: VZGenericMachineIdentifier().dataRepresentation,
            macAddress: VZMACAddress.randomLocallyAdministered().string
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: url, options: .withoutOverwriting)
        return state
    }
}
