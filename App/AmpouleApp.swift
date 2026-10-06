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

/// Shuts running VMs down before the app quits, instead of cutting their power.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let forceOffDelay: Duration = .seconds(30)

    let model = LibraryModel()

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !model.running.isEmpty else {
            return .terminateNow
        }
        model.onAllStopped = {
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        model.shutDownAll()
        Task { [model] in
            try? await Task.sleep(for: Self.forceOffDelay)
            model.forceOffAll()
        }
        return .terminateLater
    }
}
