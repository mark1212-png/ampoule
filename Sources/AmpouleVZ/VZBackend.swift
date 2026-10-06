import AmpouleCore

/// The Virtualization.framework backend (decision 0005). Linux only for now; macOS guests come next.
public struct VZBackend: VMBackend {
    public let identifier = "vz"

    public init() {}

    public func supports(_ guestOS: GuestOS) -> Bool {
        guestOS == .linux
    }
}
