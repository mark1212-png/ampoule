import AmpouleCore
import ArgumentParser
import Foundation

@main
struct AmpouleCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ampoule",
        abstract: "Create and run virtual machines on Apple Silicon.",
        version: Ampoule.version,
        subcommands: [Create.self, List.self, Validate.self]
    )
}

extension GuestOS: ExpressibleByArgument {}

struct Create: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Create a virtual machine.")

    @Argument(help: "Name of the virtual machine.")
    var name: String

    @Option(name: .customLong("os"), help: "Guest operating system: macos or linux.")
    var guestOS: GuestOS

    @Option(help: "Number of virtual CPUs.")
    var cpus = 4

    @Option(help: "Memory in MiB.")
    var memory = 4096

    @Option(help: "Disk size in GiB.")
    var disk = 64

    func validate() throws {
        if guestOS == .windows {
            throw ValidationError("Windows guests need ampoule-engine, which isn't available yet (milestone E4).")
        }
    }

    func run() throws {
        let bundle = try VMLibrary().create(name: name, guestOS: guestOS, cpuCount: cpus, memoryMiB: memory, diskSizeGiB: disk)
        print("Created \(bundle.url.path)")
    }
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List virtual machines.",
        discussion: "Exits with status 2 if any bundle in the library is invalid."
    )

    func run() throws {
        let library = VMLibrary()
        let entries = try library.entries()
        guard !entries.isEmpty else {
            print("No virtual machines in \(library.directory.path)")
            return
        }
        var foundInvalid = false
        for entry in entries {
            switch entry {
            case .valid(let bundle):
                let configuration = bundle.configuration
                print("\(configuration.name)\t\(configuration.guestOS.rawValue)\t\(configuration.cpuCount) CPU\t\(configuration.memoryMiB) MiB")
            case .invalid(let url, let reason):
                foundInvalid = true
                print("\(url.lastPathComponent)\tINVALID: \(reason)")
            }
        }
        if foundInvalid {
            throw ExitCode(2)
        }
    }
}

struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Check a VM bundle or config.json.")

    @Argument(help: "Path to a .ampoule bundle or a config.json file.")
    var path: String

    func run() throws {
        let url = URL(filePath: path)
        let configuration = url.pathExtension == VMBundle.pathExtension
            ? try VMBundle.open(at: url).configuration
            : try VMConfiguration.decode(from: Data(contentsOf: url))
        print("ok: \(configuration.name) (\(configuration.guestOS.rawValue))")
    }
}
