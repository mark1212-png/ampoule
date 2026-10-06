import AmpouleAppModel
import AmpouleCore
import AmpouleVZ
import SwiftUI
import UniformTypeIdentifiers

/// Collects settings for a new VM. Linux VMs are created immediately; macOS VMs install in the background.
struct NewVMSheet: View {
    var onCreate: (VMBundle) -> Void

    @Environment(LibraryModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var guestOS: GuestOS = .linux
    @State private var cpuCount = 4
    @State private var memoryGiB = 4
    @State private var diskSizeGiB = 64
    @State private var source: LibraryModel.RestoreImageSource = .latest
    @State private var isPickingIPSW = false
    @State private var latestDescription: String?
    @State private var errorMessage: String?

    private let maxCPUCount = ProcessInfo.processInfo.activeProcessorCount
    private let maxMemoryGiB = Int(ProcessInfo.processInfo.physicalMemory >> 30)

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name, prompt: Text(guestOS == .macOS ? "macOS" : "Ubuntu"))
                Picker("System", selection: $guestOS) {
                    Text("Linux").tag(GuestOS.linux)
                    Text("macOS").tag(GuestOS.macOS)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Windows arrives with Ampoule's own VM engine.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if guestOS == .macOS {
                Section {
                    Picker("Install from", selection: $source) {
                        Text("Latest from Apple").tag(LibraryModel.RestoreImageSource.latest)
                        if case .file(let url) = source {
                            Text(url.lastPathComponent).tag(source)
                        }
                    }
                    Button("Choose Restore Image (.ipsw)…") { isPickingIPSW = true }
                } footer: {
                    Text(macOSFooter)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Stepper("CPUs: \(cpuCount)", value: $cpuCount, in: 1...maxCPUCount)
                Stepper("Memory: \(memoryGiB) GB", value: $memoryGiB, in: 1...max(1, maxMemoryGiB / 2))
                Stepper("Disk: \(diskSizeGiB) GB", value: $diskSizeGiB, in: 8...2048, step: 8)
            } footer: {
                Text("The disk only uses space on your Mac as the VM writes to it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(guestOS == .macOS ? "Install" : "Create") { create() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .fileImporter(isPresented: $isPickingIPSW, allowedContentTypes: [UTType(filenameExtension: "ipsw") ?? .data]) { result in
            if case .success(let url) = result {
                source = .file(url)
            }
        }
        .onChange(of: guestOS) { _, newValue in
            if newValue == .macOS, memoryGiB < 8 {
                memoryGiB = min(8, max(1, maxMemoryGiB / 2))
            }
        }
        .task(id: guestOS) {
            guard guestOS == .macOS, latestDescription == nil else { return }
            if let latest = try? await MacOSInstallation.latestRestoreImage() {
                let cached = RestoreImageCache.cachedCopy(of: latest.url) != nil
                latestDescription = "macOS \(latest.version)" + (cached ? ", already downloaded" : "")
            }
        }
    }

    private var macOSFooter: String {
        let latest = latestDescription.map { "Latest: \($0). " } ?? ""
        return latest + "The first download is about 27 GB and is kept for future VMs. Apple allows two macOS VMs running at once."
    }

    private func create() {
        do {
            switch guestOS {
            case .macOS:
                try model.createMacOS(
                    name: name,
                    cpuCount: cpuCount,
                    memoryMiB: memoryGiB * 1024,
                    diskSizeGiB: diskSizeGiB,
                    source: source
                )
            default:
                let bundle = try model.create(
                    name: name,
                    guestOS: guestOS,
                    cpuCount: cpuCount,
                    memoryMiB: memoryGiB * 1024,
                    diskSizeGiB: diskSizeGiB
                )
                onCreate(bundle)
            }
            dismiss()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
