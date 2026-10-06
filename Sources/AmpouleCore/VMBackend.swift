/// A virtualization backend (decision 0005).
///
/// Implementations: Virtualization.framework (macOS, Linux) and ampoule-engine (Windows, Linux).
/// Neither exists yet; the app and CLI only talk to backends through this protocol.
public protocol VMBackend: Sendable {
    /// Short identifier, e.g. `"vz"` or `"engine"`.
    var identifier: String { get }

    /// Whether this backend can run the given guest.
    func supports(_ guestOS: GuestOS) -> Bool
}
