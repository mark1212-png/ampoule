import AmpouleCore
import Foundation
import Observation

/// The app's view of the VM library and the VMs it is running.
@MainActor
@Observable
final class LibraryModel {
    let library = VMLibrary()
    private(set) var entries: [VMLibrary.Entry] = []
    private(set) var running: [String: RunningVM] = [:]
    var errorMessage: String?

    /// Called when the last running VM stops; used to finish quitting the app.
    @ObservationIgnored var onAllStopped: (() -> Void)?

    init() {
        reload()
    }

    func reload() {
        do {
            entries = try library.entries()
        } catch {
            entries = []
            errorMessage = "Couldn't read the VM library: \(error)"
        }
    }

    func create(name: String, guestOS: GuestOS, cpuCount: Int, memoryMiB: Int, diskSizeGiB: Int) throws -> VMBundle {
        let bundle = try library.create(name: name, guestOS: guestOS, cpuCount: cpuCount, memoryMiB: memoryMiB, diskSizeGiB: diskSizeGiB)
        reload()
        return bundle
    }

    /// Starts the VM unless it's already running. Returns false and sets `errorMessage` on failure.
    @discardableResult
    func start(_ bundle: VMBundle, installMedia: URL? = nil) -> Bool {
        let name = bundle.configuration.name
        guard running[name] == nil else {
            return true
        }
        do {
            let vm = try RunningVM(bundle: bundle, installMedia: installMedia)
            vm.onStopped = { [weak self, weak vm] in
                guard let self, let vm else { return }
                if case .failed(let message) = vm.state {
                    errorMessage = "\(name) stopped with an error: \(message)"
                }
                running[name] = nil
                if running.isEmpty {
                    onAllStopped?()
                }
            }
            running[name] = vm
            Task { await vm.start() }
            return true
        } catch {
            errorMessage = String(describing: error)
            return false
        }
    }

    /// Moves a stopped VM's bundle to the Trash, where it can still be recovered.
    func moveToTrash(_ bundle: VMBundle) {
        guard running[bundle.configuration.name] == nil else {
            errorMessage = "Shut down \(bundle.configuration.name) before moving it to the Trash."
            return
        }
        do {
            try FileManager.default.trashItem(at: bundle.url, resultingItemURL: nil)
        } catch {
            errorMessage = "Couldn't move \(bundle.configuration.name) to the Trash: \(error.localizedDescription)"
        }
        reload()
    }

    func shutDownAll() {
        for vm in running.values {
            vm.shutDown()
        }
    }

    func forceOffAll() {
        for vm in running.values {
            vm.forceOff()
        }
    }
}

extension VMLibrary.Entry: @retroactive Identifiable {
    public var id: URL {
        switch self {
        case .valid(let bundle): bundle.url
        case .invalid(let url, _): url
        }
    }
}
