import AmpouleCore
import AmpouleVZ
import AppKit
import ArgumentParser
import Foundation
import Virtualization

struct Run: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start a virtual machine in a window.",
        discussion: """
            Closing the window or pressing Control-C asks the guest to shut down; doing it again forces the VM off. \
            The CLI must be signed with the virtualization entitlement: build it with scripts/build-cli.sh.
            """
    )

    @Argument(help: "Name of the virtual machine.")
    var name: String

    @Option(help: "Installer ISO to attach as a read-only USB drive for this run.")
    var iso: String?

    func run() throws {
        let bundle = try VMLibrary().bundle(named: name)
        let lock = try BundleLock(bundle: bundle)
        let installMedia = iso.map { URL(filePath: $0) }
        try MainActor.assumeIsolated {
            let session = try VZSession(bundle: bundle, installMedia: installMedia)
            let controller = VMWindowController(session: session, title: bundle.configuration.name)
            controller.run()
        }
        withExtendedLifetime(lock) {}
    }
}

/// Shows one VM in a window and runs the AppKit event loop until the VM stops.
@MainActor
final class VMWindowController: NSObject, NSWindowDelegate, NSApplicationDelegate {
    private let session: VZSession
    private let window: NSWindow
    private var interruptSource: DispatchSourceSignal?
    private var stopRequested = false

    init(session: VZSession, title: String) {
        self.session = session
        let view = VZVirtualMachineView()
        view.virtualMachine = session.virtualMachine
        view.capturesSystemKeys = true
        view.automaticallyReconfiguresDisplay = true
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = view
        window.center()
        super.init()
        window.delegate = self
    }

    func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.delegate = self
        app.mainMenu = makeMainMenu()

        session.onStop = { error in
            if error == nil {
                print("VM stopped.")
            }
            if let error {
                FileHandle.standardError.write(Data("ampoule: VM stopped with an error: \(error.localizedDescription)\n".utf8))
                exit(1)
            }
            exit(0)
        }
        installInterruptHandler()

        window.makeKeyAndOrderFront(nil)
        app.activate()
        Task {
            do {
                try await session.start()
                print("VM started. Close the window or press Control-C to shut it down.")
            } catch {
                FileHandle.standardError.write(Data("ampoule: could not start the VM: \(error.localizedDescription)\n".utf8))
                exit(1)
            }
        }
        app.run()
    }

    /// The first call asks the guest to shut down. A second call, or a guest that can't be asked, forces it off.
    private func stopVM() {
        if !stopRequested, session.requestStop() {
            stopRequested = true
            window.subtitle = "Shutting down… close again to force off"
            return
        }
        Task { try? await session.forceStop() }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        stopVM()
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        stopVM()
        return .terminateCancel
    }

    /// Control-C in the terminal asks the guest to shut down instead of killing it mid-write.
    private func installInterruptHandler() {
        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.stopVM() }
        }
        source.resume()
        interruptSource = source
    }

    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Shut Down VM and Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(appItem)
        return mainMenu
    }
}
