import AmpouleCore
import SwiftUI

/// The main window: VMs in the sidebar, the selected VM in the detail area.
struct LibraryView: View {
    @Environment(LibraryModel.self) private var model
    @State private var selection: URL?
    @State private var isCreating = false

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(selection: $selection) {
                Section("Virtual Machines") {
                    ForEach(model.entries) { entry in
                        LibraryRow(entry: entry, isRunning: isRunning(entry))
                            .tag(entry.id)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            .safeAreaInset(edge: .bottom) {
                Text("Ampoule \(Ampoule.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        } detail: {
            if let entry = model.entries.first(where: { $0.id == selection }) {
                switch entry {
                case .valid(let bundle):
                    VMDetailView(bundle: bundle)
                case .invalid(let url, let reason):
                    ContentUnavailableView(
                        "\(url.deletingPathExtension().lastPathComponent) can't be opened",
                        systemImage: "exclamationmark.triangle",
                        description: Text(reason)
                    )
                }
            } else {
                ContentUnavailableView {
                    Label(model.entries.isEmpty ? "No Virtual Machines" : "No Selection", systemImage: "shippingbox")
                } description: {
                    Text(model.entries.isEmpty ? "Create a Linux virtual machine to get started." : "Select a virtual machine.")
                } actions: {
                    Button("New Virtual Machine") { isCreating = true }
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button("New Virtual Machine", systemImage: "plus") { isCreating = true }
            }
        }
        .sheet(isPresented: $isCreating) {
            NewVMSheet { bundle in selection = bundle.url }
        }
        .alert("Ampoule", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func isRunning(_ entry: VMLibrary.Entry) -> Bool {
        guard case .valid(let bundle) = entry else { return false }
        return model.running[bundle.configuration.name] != nil
    }
}

private struct LibraryRow: View {
    let entry: VMLibrary.Entry
    let isRunning: Bool

    var body: some View {
        switch entry {
        case .valid(let bundle):
            Label {
                HStack {
                    Text(bundle.configuration.name)
                    Spacer()
                    if isRunning {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.green)
                            .accessibilityLabel("Running")
                    }
                }
            } icon: {
                Image(systemName: bundle.configuration.guestOS.symbolName)
            }
        case .invalid(let url, _):
            Label(url.deletingPathExtension().lastPathComponent, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }
}

extension GuestOS {
    var displayName: String {
        switch self {
        case .macOS: "macOS"
        case .linux: "Linux"
        case .windows: "Windows"
        }
    }

    var symbolName: String {
        switch self {
        case .macOS: "apple.logo"
        case .linux: "terminal"
        case .windows: "pc"
        }
    }
}

#Preview {
    LibraryView()
        .environment(LibraryModel())
}
