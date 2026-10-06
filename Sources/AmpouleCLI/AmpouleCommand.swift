import AmpouleCore
import AmpouleVZ
import ArgumentParser
import Foundation
import Synchronization

@main
struct AmpouleCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ampoule",
        abstract: "Create and run virtual machines on Apple Silicon.",
        version: Ampoule.version,
        subcommands: [Create.self, List.self, Run.self, Validate.self, IPSW.self]
    )
}

extension GuestOS: ExpressibleByArgument {}

struct Create: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create a virtual machine.",
        discussion: """
            macOS guests are installed from a restore image while being created: pass --ipsw with a .ipsw file, \
            or --ipsw latest to download the newest version this Mac supports (about 15–20 GB, cached in \
            ~/Library/Caches/Ampoule/RestoreImages). Control-C cancels and leaves nothing behind.
            """
    )

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

    @Option(help: "macOS only: a .ipsw restore image, or \"latest\".")
    var ipsw: String?

    func validate() throws {
        switch guestOS {
        case .windows:
            throw ValidationError("Windows guests need ampoule-engine, which isn't available yet (milestone E4).")
        case .macOS where ipsw == nil:
            throw ValidationError("macOS guests need --ipsw <file.ipsw> or --ipsw latest.")
        case .linux where ipsw != nil:
            throw ValidationError("--ipsw is for macOS guests. Linux guests install from an ISO: ampoule run <name> --iso <file>.")
        default:
            break
        }
    }

    func run() throws {
        let library = VMLibrary()
        guard guestOS == .macOS, let ipsw else {
            let bundle = try library.create(name: name, guestOS: guestOS, cpuCount: cpus, memoryMiB: memory, diskSizeGiB: disk)
            print("Created \(bundle.url.path)")
            return
        }
        let bundle = try runCancellingOnInterrupt {
            let restoreImage = try await resolveRestoreImage(ipsw)
            print("Installing macOS into \(name)…")
            let printer = ProgressPrinter(label: "Installing")
            let bundle = try await library.create(name: name, guestOS: .macOS, cpuCount: cpus, memoryMiB: memory, diskSizeGiB: disk) { staged in
                try await MacOSInstallation.install(into: staged, restoreImage: restoreImage) { fraction in
                    printer.update(fraction)
                }
            }
            printer.finish()
            return bundle
        }
        print("Created \(bundle.url.path)")
    }

    private func resolveRestoreImage(_ argument: String) async throws -> URL {
        guard argument == "latest" else {
            let file = URL(filePath: argument)
            guard FileManager.default.fileExists(atPath: file.path) else {
                throw VZBackendError.restoreImageNotFound(file.path)
            }
            return file
        }
        let latest = try await MacOSInstallation.latestRestoreImage()
        print("Latest supported macOS: \(latest.version)")
        let printer = ProgressPrinter(label: "Downloading")
        let file = try await RestoreImageCache.localCopy(of: latest.url) { written, expected in
            if expected > 0 {
                printer.update(Double(written) / Double(expected))
            }
        }
        printer.finish()
        print("Restore image: \(file.path)")
        return file
    }
}

/// Runs async main-actor work from a synchronous command, cancelling it if the user presses Control-C.
///
/// Spins the main run loop until the work finishes, the same way `ampoule run` keeps the main thread
/// serving AppKit. (An async root command would run us off the main dispatch queue, which
/// Virtualization.framework and `MainActor.assumeIsolated` don't allow.)
private func runCancellingOnInterrupt<T: Sendable>(_ operation: @escaping @MainActor () async throws -> T) throws -> T {
    try MainActor.assumeIsolated {
        let outcome = Outcome<T>()
        let task = Task { @MainActor in
            do {
                outcome.result = .success(try await operation())
            } catch {
                outcome.result = .failure(error)
            }
        }
        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler {
            FileHandle.standardError.write(Data("\nCancelling…\n".utf8))
            task.cancel()
        }
        source.resume()
        defer {
            source.cancel()
            signal(SIGINT, SIG_DFL)
        }
        while outcome.result == nil {
            _ = CFRunLoopRunInMode(.defaultMode, 0.25, false)
        }
        return try outcome.result!.get()
    }
}

@MainActor
private final class Outcome<T: Sendable> {
    var result: Result<T, Error>?
}

/// Prints "Label: 42%" on one line, updating only when the whole-percent value changes.
final class ProgressPrinter: Sendable {
    private let label: String
    private let lastPercent = Mutex(-1)

    init(label: String) {
        self.label = label
    }

    func update(_ fraction: Double) {
        let percent = Int((min(max(fraction, 0), 1) * 100).rounded(.down))
        let changed = lastPercent.withLock { last in
            defer { last = percent }
            return last != percent
        }
        if changed {
            FileHandle.standardOutput.write(Data("\r\(label): \(percent)%".utf8))
        }
    }

    func finish() {
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}

struct IPSW: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ipsw",
        abstract: "Show the newest macOS restore image this Mac can virtualize."
    )

    func run() throws {
        let latest = try runCancellingOnInterrupt { try await MacOSInstallation.latestRestoreImage() }
        print("macOS \(latest.version)")
        print(latest.url.absoluteString)
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
