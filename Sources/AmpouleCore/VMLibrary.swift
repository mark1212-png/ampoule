import Foundation

/// The directory holding all of the user's VM bundles.
public struct VMLibrary: Sendable {
    /// A bundle found in the library. Broken bundles are reported, never silently skipped.
    public enum Entry: Sendable {
        case valid(VMBundle)
        case invalid(url: URL, reason: String)
    }

    /// `$AMPOULE_HOME` if set, otherwise `~/Library/Application Support/Ampoule/VMs`.
    public static var defaultDirectory: URL {
        if let home = ProcessInfo.processInfo.environment["AMPOULE_HOME"], !home.isEmpty {
            return URL(filePath: home, directoryHint: .isDirectory)
        }
        return URL.applicationSupportDirectory.appending(path: "Ampoule/VMs", directoryHint: .isDirectory)
    }

    public let directory: URL

    public init(directory: URL = VMLibrary.defaultDirectory) {
        self.directory = directory
    }

    /// All bundles in the library, sorted by file name. An absent library directory is an empty library.
    public func entries() throws -> [Entry] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }
        return try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            .filter { $0.pathExtension == VMBundle.pathExtension }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { url in
                do {
                    return .valid(try VMBundle.open(at: url))
                } catch {
                    return .invalid(url: url, reason: String(describing: error))
                }
            }
    }

    /// Opens the bundle for the VM called `name`.
    public func bundle(named name: String) throws -> VMBundle {
        try VMBundle.validateName(name)
        let url = directory.appending(path: "\(name).\(VMBundle.pathExtension)", directoryHint: .isDirectory)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw BundleError.notFound(name)
        }
        return try VMBundle.open(at: url)
    }

    public func create(name: String, guestOS: GuestOS, cpuCount: Int, memoryMiB: Int, diskSizeGiB: Int) throws -> VMBundle {
        try VMBundle.create(
            in: directory,
            name: name,
            guestOS: guestOS,
            cpuCount: cpuCount,
            memoryMiB: memoryMiB,
            diskSizeGiB: diskSizeGiB
        )
    }

    @MainActor
    public func create(
        name: String,
        guestOS: GuestOS,
        cpuCount: Int,
        memoryMiB: Int,
        diskSizeGiB: Int,
        prepare: (VMBundle) async throws -> Void
    ) async throws -> VMBundle {
        try await VMBundle.create(
            in: directory,
            name: name,
            guestOS: guestOS,
            cpuCount: cpuCount,
            memoryMiB: memoryMiB,
            diskSizeGiB: diskSizeGiB,
            prepare: prepare
        )
    }
}
