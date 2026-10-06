import SwiftUI
import Virtualization

/// One VM's screen. Closing the window leaves the VM running; it stays listed as running in the library.
struct VMWindowView: View {
    let name: String

    @Environment(LibraryModel.self) private var model

    var body: some View {
        Group {
            if let vm = model.running[name] {
                VMDisplay(virtualMachine: vm.session.virtualMachine)
                    .ignoresSafeArea()
                    .toolbar {
                        ToolbarItemGroup {
                            Button("Shut Down", systemImage: "power") { vm.shutDown() }
                                .help("Ask \(name) to shut down")
                                .disabled(vm.state != .running)
                            Button("Force Off", systemImage: "bolt.slash") { vm.forceOff() }
                                .help("Turn \(name) off immediately, like pulling the power cord")
                        }
                    }
                    .navigationSubtitle(vm.state == .stopping ? "Shutting down…" : "")
            } else {
                ContentUnavailableView("\(name) isn't running", systemImage: "power", description: Text("Start it from the library."))
            }
        }
        .navigationTitle(name)
    }
}

private struct VMDisplay: NSViewRepresentable {
    let virtualMachine: VZVirtualMachine

    func makeNSView(context: Context) -> VZVirtualMachineView {
        let view = VZVirtualMachineView()
        view.capturesSystemKeys = true
        view.automaticallyReconfiguresDisplay = true
        view.virtualMachine = virtualMachine
        return view
    }

    func updateNSView(_ view: VZVirtualMachineView, context: Context) {
        if view.virtualMachine !== virtualMachine {
            view.virtualMachine = virtualMachine
        }
    }
}
