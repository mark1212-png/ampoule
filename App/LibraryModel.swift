import AmpouleCore
import AmpouleVZ
import Foundation
import Observation

/// The app's view of the VM library and the VMs it is running.
@MainActor
@Observable
final class LibraryModel {
    let library = VMLibrary()
    private(set) var entries: [VMLibrary.Entry] = []
    private(set) var running: [String: RunningVM] = [:]
    private(set) var installations: [Installation] = []
    var errorMessage: String?

    /// Called once no VM is running and no installation is in progress; used to finish quitting the app.
    @ObservationIgnored var onAllStopped: (() -> Void)?

    enum RestoreImageSource: Hashable {
        case latest
        case file(URL)
    }

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
                notifyIfIdle()
            }
            running[name] = vm
            Task { await vm.start() }
            return true
        } catch {
            errorMessage = String(describing: error)
            return false
        }
    }

    /// Saves a stopped VM's shared folders. Fails (with `errorMessage`) if the VM is running.
    func setSharedFolders(_ folders: [SharedFolder], for bundle: VMBundle) {
        var configuration = bundle.configuration
        configuration.sharedFolders = folders
        do {
            _ = try bundle.updatingConfiguration(configuration)
        } catch {
            errorMessage = String(describing: error)
        }
        reload()
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

    /// Checks the name, then downloads (if needed) and installs macOS in the background.
    /// The VM appears in the library once installation finishes.
    func createMacOS(name: String, cpuCount: Int, memoryMiB: Int, diskSizeGiB: Int, source: RestoreImageSource) throws {
        try VMBundle.validateName(name)
        guard !library.containsBundle(named: name), !installations.contains(where: { $0.name == name }) else {
            throw BundleError.alreadyExists(name)
        }
        let installation = Installation(name: name)
        installations.append(installation)
        installation.task = Task { [library] in
            do {
                let restoreImage: URL
                switch source {
                case .file(let url):
                    restoreImage = url
                case .latest:
                    let latest = try await MacOSInstallation.latestRestoreImage()
                    let report = installation.progressReporter { .downloading($0) }
                    restoreImage = try await RestoreImageCache.localCopy(of: latest.url) { written, expected in
                        if expected > 0 { report(Double(written) / Double(expected)) }
                    }
                }
                installation.phase = .installing(0)
                let report = installation.progressReporter { .installing($0) }
                _ = try await library.create(
                    name: name, guestOS: .macOS, cpuCount: cpuCount, memoryMiB: memoryMiB, diskSizeGiB: diskSizeGiB
                ) { staged in
                    try await MacOSInstallation.install(into: staged, restoreImage: restoreImage, progress: report)
                }
            } catch is CancellationError {
                // Cancelled by the user or by quitting: nothing to report.
            } catch {
                if !Task.isCancelled {
                    errorMessage = "Couldn't create \(name): \(error)"
                }
            }
            installations.removeAll { $0 === installation }
            reload()
            notifyIfIdle()
        }
    }

    func cancelAllInstallations() {
        for installation in installations {
            installation.cancel()
        }
    }

    var isIdle: Bool {
        running.isEmpty && installations.isEmpty
    }

    private func notifyIfIdle() {
        if isIdle {
            onAllStopped?()
        }
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
