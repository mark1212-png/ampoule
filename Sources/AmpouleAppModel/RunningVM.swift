import AmpouleCore
import AmpouleVZ
import Foundation
import Observation
import Virtualization

/// A VM the app has started. Holds the bundle lock for as long as the VM runs.
@MainActor
@Observable
public final class RunningVM {
    public enum State: Equatable, Sendable {
        case starting
        case running
        case stopping
        case stopped
        case failed(String)
    }

    public let name: String
    public let session: VZSession
    public private(set) var state: State = .starting

    /// Called once when the VM has stopped for any reason.
    var onStopped: (() -> Void)?

    @ObservationIgnored private let lock: BundleLock

    init(bundle: VMBundle, installMedia: URL?) throws {
        name = bundle.configuration.name
        lock = try BundleLock(bundle: bundle)
        session = try VZSession(bundle: bundle, installMedia: installMedia)
        session.onStop = { [weak self] error in
            guard let self else { return }
            state = error.map { .failed($0.localizedDescription) } ?? .stopped
            onStopped?()
        }
    }

    func start() async {
        do {
            try await session.start()
            state = .running
        } catch {
            state = .failed(error.localizedDescription)
            onStopped?()
        }
    }

    /// Asks the guest to shut down. Forces it off if the guest can't be asked.
    public func shutDown() {
        if session.requestStop() {
            state = .stopping
        } else {
            forceOff()
        }
    }

    public func forceOff() {
        Task { try? await session.forceStop() }
    }
}
