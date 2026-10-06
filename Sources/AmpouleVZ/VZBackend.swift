import AmpouleCore

/// The Virtualization.framework backend (decision 0005): macOS and Linux guests.
public struct VZBackend: VMBackend {
    public let identifier = "vz"

    public init() {}

    public func supports(_ guestOS: GuestOS) -> Bool {
        guestOS == .linux || guestOS == .macOS
    }
}
