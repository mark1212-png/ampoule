import AmpouleCore
import ArgumentParser
import Foundation

struct Share: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Share folders on this Mac with a virtual machine.",
        discussion: """
            macOS guests see shared folders in /Volumes/My Shared Files. Linux guests mount them with: \\
            mount -t virtiofs ampoule /mnt/shared. Changes take effect the next time the VM starts, \\
            and can't be made while it's running.
            """,
        subcommands: [Add.self, Remove.self, List.self]
    )

    struct Add: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Share a folder with a VM.")

        @Argument(help: "Name of the virtual machine.")
        var name: String

        @Argument(help: "Folder on this Mac.")
        var folder: String

        @Flag(help: "Don't let the guest change the folder.")
        var readOnly = false

        func run() throws {
            let path = URL(filePath: folder).standardizedFileURL.path
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw CLIError("\"\(path)\" isn't a folder.")
            }
            let bundle = try VMLibrary().bundle(named: name)
            var configuration = bundle.configuration
            guard !configuration.sharedFolders.contains(where: { $0.path == path }) else {
                throw CLIError("\"\(path)\" is already shared with \(name).")
            }
            configuration.sharedFolders.append(SharedFolder(path: path, readOnly: readOnly))
            _ = try bundle.updatingConfiguration(configuration)
            print("Shared \(path) with \(name)\(readOnly ? " (read-only)" : "") as \"\(SharedFolder(path: path).name)\".")
        }
    }

    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Stop sharing a folder with a VM.")

        @Argument(help: "Name of the virtual machine.")
        var name: String

        @Argument(help: "Shared folder: its path on this Mac, or its name as the guest sees it.")
        var folder: String

        func run() throws {
            let bundle = try VMLibrary().bundle(named: name)
            var configuration = bundle.configuration
            let path = URL(filePath: folder).standardizedFileURL.path
            let before = configuration.sharedFolders.count
            configuration.sharedFolders.removeAll { $0.path == path || $0.name == folder }
            guard configuration.sharedFolders.count < before else {
                throw CLIError("\(name) doesn't share \"\(folder)\".")
            }
            _ = try bundle.updatingConfiguration(configuration)
            print("Stopped sharing \(folder) with \(name).")
        }
    }

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List a VM's shared folders.")

        @Argument(help: "Name of the virtual machine.")
        var name: String

        func run() throws {
            let folders = try VMLibrary().bundle(named: name).configuration.sharedFolders
            guard !folders.isEmpty else {
                print("\(name) has no shared folders.")
                return
            }
            for folder in folders {
                print("\(folder.name)\t\(folder.path)\(folder.readOnly ? "\tread-only" : "")")
            }
        }
    }
}

/// An error found while a command runs. Unlike `ValidationError`, it isn't followed by usage help,
/// because the command line itself was fine.
struct CLIError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
