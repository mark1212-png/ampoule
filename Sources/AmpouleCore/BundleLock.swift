import Darwin
import Foundation

/// An exclusive lock on a bundle, held while its VM runs. Two VMs writing one disk would corrupt it.
///
/// Uses `flock(2)` on `<bundle>/.lock`; the kernel releases it if the process exits or crashes.
public final class BundleLock {
    public static let fileName = ".lock"

    private let fileDescriptor: Int32

    public init(bundle: VMBundle) throws {
        let path = bundle.url.appending(path: Self.fileName).path
        let descriptor = open(path, O_RDWR | O_CREAT | O_CLOEXEC, 0o644)
        guard descriptor >= 0 else {
            throw BundleError.cannotLock(bundle.configuration.name)
        }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw BundleError.alreadyRunning(bundle.configuration.name)
        }
        fileDescriptor = descriptor
    }

    deinit {
        flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
    }
}
