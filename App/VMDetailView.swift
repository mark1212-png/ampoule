import AmpouleAppModel
import AmpouleCore
import SwiftUI
import UniformTypeIdentifiers

/// Details and actions for one VM in the library.
struct VMDetailView: View {
    let bundle: VMBundle

    @Environment(LibraryModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @State private var isPickingISO = false
    @State private var isPickingFolder = false
    @State private var isConfirmingTrash = false

    private var configuration: VMConfiguration { bundle.configuration }
    private var runningVM: RunningVM? { model.running[configuration.name] }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: configuration.guestOS.symbolName)
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(configuration.name)
                    .font(.largeTitle.weight(.semibold))
                Text(statusText)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow { Text("System").foregroundStyle(.secondary); Text(configuration.guestOS.displayName) }
                GridRow { Text("CPUs").foregroundStyle(.secondary); Text("\(configuration.cpuCount)") }
                GridRow { Text("Memory").foregroundStyle(.secondary); Text("\(configuration.memoryMiB / 1024) GB") }
                GridRow { Text("Disk").foregroundStyle(.secondary); Text(diskSizeText) }
            }
            .padding(20)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))

            sharedFoldersCard

            HStack(spacing: 12) {
                if runningVM == nil {
                    Button("Start", systemImage: "play.fill") { start(installMedia: nil) }
                        .buttonStyle(.glassProminent)
                    Button("Start from ISO…", systemImage: "opticaldisc") { isPickingISO = true }
                        .buttonStyle(.glass)
                } else {
                    Button("Show Window", systemImage: "macwindow") { openWindow(id: "vm", value: configuration.name) }
                        .buttonStyle(.glassProminent)
                }
            }
            .controlSize(.large)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup {
                Button("Show in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([bundle.url])
                }
                Button("Move to Trash", systemImage: "trash") { isConfirmingTrash = true }
                    .disabled(runningVM != nil)
            }
        }
        .fileImporter(isPresented: $isPickingISO, allowedContentTypes: [.diskImage, .data]) { result in
            if case .success(let url) = result {
                start(installMedia: url)
            }
        }
        .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                let path = url.standardizedFileURL.path
                guard !configuration.sharedFolders.contains(where: { $0.path == path }) else { return }
                model.setSharedFolders(configuration.sharedFolders + [SharedFolder(path: path)], for: bundle)
            }
        }
        .confirmationDialog("Move \(configuration.name) to the Trash?", isPresented: $isConfirmingTrash) {
            Button("Move to Trash", role: .destructive) { model.moveToTrash(bundle) }
        } message: {
            Text("Its disk and settings go to the Trash. You can restore them from there until you empty it.")
        }
    }

    private var sharedFoldersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Shared Folders").font(.headline)
                Spacer()
                Button("Add Folder…", systemImage: "plus") { isPickingFolder = true }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Share a folder on this Mac with \(configuration.name)")
            }
            if configuration.sharedFolders.isEmpty {
                Text("None").foregroundStyle(.secondary)
            }
            ForEach(configuration.sharedFolders, id: \.path) { folder in
                HStack {
                    Image(systemName: "folder")
                    Text(folder.name)
                        .help(folder.path)
                    Spacer()
                    Toggle("Read-only", isOn: Binding(
                        get: { folder.readOnly },
                        set: { readOnly in
                            let folders = configuration.sharedFolders.map {
                                $0.path == folder.path ? SharedFolder(path: $0.path, readOnly: readOnly) : $0
                            }
                            model.setSharedFolders(folders, for: bundle)
                        }
                    ))
                    .toggleStyle(.checkbox)
                    Button("Remove", systemImage: "minus.circle") {
                        model.setSharedFolders(configuration.sharedFolders.filter { $0.path != folder.path }, for: bundle)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }
            Text(sharedFoldersHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(runningVM != nil)
        .padding(20)
        .frame(maxWidth: 420)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private var sharedFoldersHint: String {
        if runningVM != nil {
            return "Shut down \(configuration.name) to change shared folders."
        }
        return configuration.guestOS == .macOS
            ? "Appears in the guest at /Volumes/My Shared Files."
            : "In the guest: mount -t virtiofs ampoule /mnt/shared"
    }

    private func start(installMedia: URL?) {
        if model.start(bundle, installMedia: installMedia) {
            openWindow(id: "vm", value: configuration.name)
        }
    }

    private var statusText: String {
        switch runningVM?.state {
        case nil, .stopped: "Stopped"
        case .starting: "Starting…"
        case .running: "Running"
        case .stopping: "Shutting down…"
        case .failed(let message): "Error: \(message)"
        }
    }

    private var diskSizeText: String {
        let sizes = configuration.disks.compactMap { disk in
            try? bundle.url(for: disk).resourceValues(forKeys: [.fileSizeKey]).fileSize
        }
        return ByteCountFormatter.string(fromByteCount: Int64(sizes.reduce(0, +)), countStyle: .file)
    }
}
