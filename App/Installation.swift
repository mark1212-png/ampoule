import Foundation
import Observation
import Synchronization

/// A macOS VM being downloaded and installed in the background.
@MainActor
@Observable
final class Installation: Identifiable {
    enum Phase: Equatable {
        case preparing
        case downloading(Double)
        case installing(Double)
    }

    let name: String
    var phase: Phase = .preparing
    @ObservationIgnored var task: Task<Void, Never>?

    nonisolated var id: String { name }

    init(name: String) {
        self.name = name
    }

    func cancel() {
        task?.cancel()
    }

    var statusText: String {
        switch phase {
        case .preparing: "Preparing…"
        case .downloading(let fraction): "Downloading macOS… \(Int(fraction * 100))%"
        case .installing(let fraction): "Installing macOS… \(Int(fraction * 100))%"
        }
    }

    var fraction: Double? {
        switch phase {
        case .preparing: nil
        case .downloading(let fraction), .installing(let fraction): fraction
        }
    }

    /// Returns a callback, safe to call from any thread, that updates the phase at most once per whole percent.
    func progressReporter(_ makePhase: @escaping @Sendable (Double) -> Phase) -> @Sendable (Double) -> Void {
        let lastPercent = Mutex(-1)
        return { [weak self] fraction in
            let percent = Int(fraction * 100)
            let changed = lastPercent.withLock { last in
                defer { last = percent }
                return last != percent
            }
            guard changed else { return }
            Task { @MainActor in self?.phase = makePhase(fraction) }
        }
    }
}
