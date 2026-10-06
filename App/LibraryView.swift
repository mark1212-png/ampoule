import AmpouleCore
import SwiftUI

/// The main window: VM list in the sidebar, the selected VM (or an empty state) in the detail area.
struct LibraryView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Section("Virtual Machines") {}
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            .safeAreaInset(edge: .bottom) {
                Text("Ampoule \(Ampoule.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        } detail: {
            ContentUnavailableView {
                Label("No Virtual Machines", systemImage: "shippingbox")
            } description: {
                Text("Create a macOS or Linux virtual machine to get started.")
            } actions: {
                Button("New Virtual Machine") {}
                    .buttonStyle(.glassProminent)
                    .disabled(true)
                    .help("Coming in v0.1")
            }
        }
        .toolbar {
            ToolbarItem {
                Button("New Virtual Machine", systemImage: "plus") {}
                    .disabled(true)
                    .help("Coming in v0.1")
            }
        }
    }
}

#Preview {
    LibraryView()
}
