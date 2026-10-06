import Foundation

/// A VM on disk: a `<name>.ampoule` directory holding `config.json` and the VM's disks.
public struct VMBundle: Sendable {
    public static let pathExtension = "ampoule"
    public static let configurationFileName = "config.json"
    public static let primaryDiskFileName = "disk.img"
    public static let diskSizeRangeGiB = 1...2048
    public static let maximumNameLength = 64

    public let url: URL
    public let configuration: VMConfiguration

    public func url(for disk: DiskConfiguration) -> URL {
        url.appending(path: disk.path, directoryHint: .notDirectory)
    }

    /// Opens an existing bundle. Fails if the configuration is invalid or any disk is missing.
    public static func open(at url: URL) throws -> VMBundle {
        guard url.pathExtension == pathExtension else {
            throw BundleError.notABundle(url.lastPathComponent)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url.appending(path: configurationFileName))
        } catch {
            throw BundleError.missingConfiguration(url.lastPathComponent)
        }
        let bundle = VMBundle(url: url, configuration: try VMConfiguration.decode(from: data))
        for disk in bundle.configuration.disks where !FileManager.default.fileExists(atPath: bundle.url(for: disk).path) {
            throw BundleError.missingDisk(disk.path)
        }
        return bundle
    }

    /// Creates a bundle in `directory` with one empty sparse disk.
    ///
    /// The bundle is assembled in a hidden staging directory and moved into place at the end,
    /// so a failure never leaves a half-created VM behind.
    public static func create(
        in directory: URL,
        name: String,
        guestOS: GuestOS,
        cpuCount: Int,
        memoryMiB: Int,
        diskSizeGiB: Int
    ) throws -> VMBundle {
        let staged = try stage(in: directory, name: name, guestOS: guestOS, cpuCount: cpuCount, memoryMiB: memoryMiB, diskSizeGiB: diskSizeGiB)
        return try commit(staged, in: directory)
    }

    /// Like `create`, but runs `prepare` on the staged bundle before moving it into place.
    /// Used for macOS guests, whose bundle is only complete once macOS is installed.
    /// If `prepare` throws or is cancelled, the staged bundle is deleted.
    @MainActor
    public static func create(
        in directory: URL,
        name: String,
        guestOS: GuestOS,
        cpuCount: Int,
        memoryMiB: Int,
        diskSizeGiB: Int,
        prepare: (VMBundle) async throws -> Void
    ) async throws -> VMBundle {
        let staged = try stage(in: directory, name: name, guestOS: guestOS, cpuCount: cpuCount, memoryMiB: memoryMiB, diskSizeGiB: diskSizeGiB)
        do {
            try await prepare(staged)
            try Task.checkCancellation()
        } catch {
            try? FileManager.default.removeItem(at: staged.url)
            throw error
        }
        return try commit(staged, in: directory)
    }

    /// Writes a complete bundle into a hidden staging directory inside `directory`.
    private static func stage(
        in directory: URL,
        name: String,
        guestOS: GuestOS,
        cpuCount: Int,
        memoryMiB: Int,
        diskSizeGiB: Int
    ) throws -> VMBundle {
        try validateName(name)
        guard diskSizeRangeGiB.contains(diskSizeGiB) else {
            throw BundleError.diskSizeOutOfRange(diskSizeGiB)
        }
        let configuration = VMConfiguration(
            name: name,
            guestOS: guestOS,
            cpuCount: cpuCount,
            memoryMiB: memoryMiB,
            disks: [DiskConfiguration(path: primaryDiskFileName)]
        )
        try configuration.validate()

        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: destination(for: name, in: directory).path) else {
            throw BundleError.alreadyExists(name)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let staging = directory.appending(path: ".\(name).\(UUID().uuidString).partial", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(configuration).write(to: staging.appending(path: configurationFileName))
            try createSparseFile(at: staging.appending(path: primaryDiskFileName), sizeBytes: UInt64(diskSizeGiB) << 30)
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
        return VMBundle(url: staging, configuration: configuration)
    }

    /// Moves a staged bundle to its final name. Fails rather than overwrites if that name appeared meanwhile.
    private static func commit(_ staged: VMBundle, in directory: URL) throws -> VMBundle {
        let destination = destination(for: staged.configuration.name, in: directory)
        do {
            try FileManager.default.moveItem(at: staged.url, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: staged.url)
            throw error
        }
        return VMBundle(url: destination, configuration: staged.configuration)
    }

    private static func destination(for name: String, in directory: URL) -> URL {
        directory.appending(path: "\(name).\(pathExtension)", directoryHint: .isDirectory)
    }

    static func validateName(_ name: String) throws(BundleError) {
        let isInvalid = name.isEmpty
            || name.count > maximumNameLength
            || name.hasPrefix(".")
            || name.contains("/")
            || name.contains(":")
            || name != name.trimmingCharacters(in: .whitespacesAndNewlines)
        if isInvalid {
            throw .invalidName(name)
        }
    }

    /// A file whose logical size is `sizeBytes` but which takes no space until the guest writes to it.
    private static func createSparseFile(at url: URL, sizeBytes: UInt64) throws {
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw BundleError.cannotCreateDisk(url.lastPathComponent)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.truncate(atOffset: sizeBytes)
    }
}

public enum BundleError: Error, Equatable, CustomStringConvertible {
    case notABundle(String)
    case missingConfiguration(String)
    case missingDisk(String)
    case invalidName(String)
    case alreadyExists(String)
    case diskSizeOutOfRange(Int)
    case cannotCreateDisk(String)
    case notFound(String)
    case cannotLock(String)
    case alreadyRunning(String)

    public var description: String {
        switch self {
        case .notABundle(let name):
            "\"\(name)\" is not an .\(VMBundle.pathExtension) bundle."
        case .missingConfiguration(let name):
            "\"\(name)\" has no readable \(VMBundle.configurationFileName)."
        case .missingDisk(let path):
            "Disk \"\(path)\" is missing from the bundle."
        case .invalidName(let name):
            "\"\(name)\" is not a valid VM name: use up to \(VMBundle.maximumNameLength) characters, without \"/\", \":\", a leading \".\" or surrounding spaces."
        case .alreadyExists(let name):
            "A VM named \"\(name)\" already exists."
        case .diskSizeOutOfRange(let size):
            "Disk size \(size) GiB is outside \(VMBundle.diskSizeRangeGiB)."
        case .cannotCreateDisk(let name):
            "Could not create disk \"\(name)\"."
        case .notFound(let name):
            "No VM named \"\(name)\"."
        case .cannotLock(let name):
            "Could not create the lock file for \"\(name)\"."
        case .alreadyRunning(let name):
            "\"\(name)\" is already running."
        }
    }
}
