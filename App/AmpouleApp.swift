import AmpouleAppModel
import AppKit
import SwiftUI

@main
struct AmpouleApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Window("Ampoule", id: "library") {
            LibraryView()
                .environment(appDelegate.model)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Reload Library") { appDelegate.model.reload() }
                    .keyboardShortcut("r")
            }
        }

        WindowGroup("Virtual Machine", id: "vm", for: String.self) { $name in
            VMWindowView(name: name ?? "")
                .environment(appDelegate.model)
        }
        .defaultSize(width: 1280, height: 800)
    }
}

/// Shuts running VMs down and cancels installations before the app quits.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let forceOffDelay: Duration = .seconds(30)

    let model = LibraryModel()

    /// Cancels installations (they leave nothing behind) and asks running guests to shut down before quitting.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !model.isIdle else {
            return .terminateNow
        }
        model.onAllStopped = {
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        model.cancelAllInstallations()
        model.shutDownAll()
        Task { [model] in
            try? await Task.sleep(for: Self.forceOffDelay)
            model.forceOffAll()
        }
        return .terminateLater
    }
}
