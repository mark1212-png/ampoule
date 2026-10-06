import Foundation

/// Guest operating systems Ampoule supports (decision 0001).
public enum GuestOS: String, Codable, Sendable, CaseIterable {
    case macOS = "macos"
    case linux
    case windows
}

/// A virtual disk attached to a VM. `path` is relative to the `.ampoule` bundle.
public struct DiskConfiguration: Codable, Sendable, Equatable {
    public var path: String
    public var readOnly: Bool

    public init(path: String, readOnly: Bool = false) {
        self.path = path
        self.readOnly = readOnly
    }
}

/// A folder on the Mac shared with the guest. Its name in the guest is the folder's own name.
public struct SharedFolder: Codable, Sendable, Equatable, Hashable {
    /// Absolute path on the Mac.
    public var path: String
    public var readOnly: Bool

    public init(path: String, readOnly: Bool = false) {
        self.path = path
        self.readOnly = readOnly
    }

    /// The name the guest sees.
    public var name: String {
        URL(filePath: path).lastPathComponent
    }
}

/// The contents of a bundle's `config.json`.
///
/// Configurations fail closed: `validate()` rejects anything Ampoule can't run exactly as written,
/// rather than substituting defaults.
public struct VMConfiguration: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1
    public static let cpuCountRange = 1...64
    public static let minimumMemoryMiB = 512

    public var schemaVersion: Int
    public var name: String
    public var guestOS: GuestOS
    public var cpuCount: Int
    public var memoryMiB: Int
    public var disks: [DiskConfiguration]
    public var sharedFolders: [SharedFolder]

    public init(
        name: String,
        guestOS: GuestOS,
        cpuCount: Int,
        memoryMiB: Int,
        disks: [DiskConfiguration],
        sharedFolders: [SharedFolder] = [],
        schemaVersion: Int = VMConfiguration.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.guestOS = guestOS
        self.cpuCount = cpuCount
        self.memoryMiB = memoryMiB
        self.disks = disks
        self.sharedFolders = sharedFolders
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, name, guestOS, cpuCount, memoryMiB, disks, sharedFolders
    }

    /// `sharedFolders` may be absent (bundles created before shared folders existed); absent means none,
    /// which shares less, never more. Every other field is required.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        name = try container.decode(String.self, forKey: .name)
        guestOS = try container.decode(GuestOS.self, forKey: .guestOS)
        cpuCount = try container.decode(Int.self, forKey: .cpuCount)
        memoryMiB = try container.decode(Int.self, forKey: .memoryMiB)
        disks = try container.decode([DiskConfiguration].self, forKey: .disks)
        sharedFolders = try container.decodeIfPresent([SharedFolder].self, forKey: .sharedFolders) ?? []
    }

    /// Throws the first problem found.
    public func validate() throws(ConfigurationError) {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw .unsupportedSchemaVersion(schemaVersion)
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw .emptyName
        }
        guard Self.cpuCountRange.contains(cpuCount) else {
            throw .cpuCountOutOfRange(cpuCount)
        }
        guard memoryMiB >= Self.minimumMemoryMiB else {
            throw .memoryTooSmall(memoryMiB)
        }
        guard !disks.isEmpty else {
            throw .noDisks
        }
        for disk in disks where disk.path.isEmpty || disk.path.hasPrefix("/") || disk.path.split(separator: "/").contains("..") {
            throw .diskPathOutsideBundle(disk.path)
        }
        var sharedNames: Set<String> = []
        for folder in sharedFolders {
            guard folder.path.hasPrefix("/"), folder.path != "/" else {
                throw .sharedFolderPathNotAbsolute(folder.path)
            }
            guard sharedNames.insert(folder.name).inserted else {
                throw .duplicateSharedFolderName(folder.name)
            }
        }
    }

    /// Decodes and validates a configuration from JSON.
    public static func decode(from data: Data) throws -> VMConfiguration {
        let configuration = try JSONDecoder().decode(VMConfiguration.self, from: data)
        try configuration.validate()
        return configuration
    }
}

public enum ConfigurationError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchemaVersion(Int)
    case emptyName
    case cpuCountOutOfRange(Int)
    case memoryTooSmall(Int)
    case noDisks
    case diskPathOutsideBundle(String)
    case sharedFolderPathNotAbsolute(String)
    case duplicateSharedFolderName(String)

    public var description: String {
        switch self {
        case .unsupportedSchemaVersion(let version):
            "Unsupported schema version \(version); this build reads version \(VMConfiguration.currentSchemaVersion)."
        case .emptyName:
            "The VM name is empty."
        case .cpuCountOutOfRange(let count):
            "CPU count \(count) is outside \(VMConfiguration.cpuCountRange)."
        case .memoryTooSmall(let mib):
            "Memory \(mib) MiB is below the \(VMConfiguration.minimumMemoryMiB) MiB minimum."
        case .noDisks:
            "The VM has no disks."
        case .diskPathOutsideBundle(let path):
            "Disk path \"\(path)\" must be a relative path inside the bundle."
        case .sharedFolderPathNotAbsolute(let path):
            "Shared folder \"\(path)\" must be an absolute path to a folder other than /."
        case .duplicateSharedFolderName(let name):
            "Two shared folders are named \"\(name)\". The guest sees folders by name, so names must be unique."
        }
    }
}
