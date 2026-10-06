import AmpouleCore
import SwiftUI

/// Collects settings for a new VM and creates its bundle.
struct NewVMSheet: View {
    var onCreate: (VMBundle) -> Void

    @Environment(LibraryModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var cpuCount = 4
    @State private var memoryGiB = 4
    @State private var diskSizeGiB = 64
    @State private var errorMessage: String?

    private let maxCPUCount = ProcessInfo.processInfo.activeProcessorCount
    private let maxMemoryGiB = Int(ProcessInfo.processInfo.physicalMemory >> 30)

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name, prompt: Text("Ubuntu"))
                LabeledContent("System") {
                    Text("Linux")
                }
            } footer: {
                Text("macOS guests come next. Windows arrives with Ampoule's own VM engine.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .frame(width: 420)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { create() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func create() {
        do {
            let bundle = try model.create(
                name: name,
                guestOS: .linux,
                cpuCount: cpuCount,
                memoryMiB: memoryGiB * 1024,
                diskSizeGiB: diskSizeGiB
            )
            onCreate(bundle)
            dismiss()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
