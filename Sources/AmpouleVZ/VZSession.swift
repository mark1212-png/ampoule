import AmpouleCore
import Foundation
import Virtualization

/// One running VM. Owns the `VZVirtualMachine` and reports when the guest stops.
@MainActor
public final class VZSession: NSObject, VZVirtualMachineDelegate {
    public let virtualMachine: VZVirtualMachine

    /// Called once when the VM stops: `nil` for a clean guest shutdown, otherwise the error.
    public var onStop: ((Error?) -> Void)?

    public init(bundle: VMBundle, installMedia: URL? = nil) throws {
        virtualMachine = VZVirtualMachine(
            configuration: try VZConfigurationBuilder.makeConfiguration(for: bundle, installMedia: installMedia)
        )
        super.init()
        virtualMachine.delegate = self
    }

    public func start() async throws {
        try await virtualMachine.start()
    }

    /// Asks the guest to shut down, like pressing a power button. Returns false if the guest can't be asked.
    public func requestStop() -> Bool {
        guard virtualMachine.canRequestStop else {
            return false
        }
        do {
            try virtualMachine.requestStop()
            return true
        } catch {
            return false
        }
    }

    /// Stops the VM immediately, like pulling the power cord.
    public func forceStop() async throws {
        try await virtualMachine.stop()
        onStop?(nil)
    }

    public nonisolated func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        MainActor.assumeIsolated { onStop?(nil) }
    }

    public nonisolated func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error) {
        MainActor.assumeIsolated { onStop?(error) }
    }
}
