# Ampoule — Design Notes

Open-source Parallels Desktop replacement for Apple Silicon Macs.
SwiftUI + Liquid Glass shell; Virtualization.framework for macOS guests, **our own VM engine on Hypervisor.framework** for Windows (and eventually full-featured Linux).

## Project goals

- Fully functional, public open-source project on GitHub; flagship portfolio piece.
- Ship small, working, demoable releases rather than one big v1.
- Show engineering rigor: tests, fail-closed checks, decision records, honest docs.
- README includes a "How this was built" section: what the author designed vs. what AI agents implemented.
- A Python/data companion (SDK and/or benchmark + telemetry analysis) ties the project to a Python/SQL/data skill set.

## Roadmap (6–8 h/week)

Weekly rhythm: ~1 h plan/review, ~5 h build sessions, ~1 h docs + reading the code that was written.
Every milestone ends with a tagged GitHub release, a README update, and a short walkthrough doc
explaining the code in the author's own words, so all of it can be discussed in interviews.

### App track

| Milestone | Scope | Est. |
|-----------|-------|------|
| **v0.1** | VZ backend: macOS + Linux guests. Liquid Glass library + VM window, create/run/stop/delete, virtiofs shared folders, `ampoule` CLI, unit tests + GitHub Actions build, README with demo GIF + "How this was built" | ~5–6 wks |
| **v0.2** | Snapshots (save state + APFS clones), clipboard (SPICE for Linux), guest agent v0 (Rust, vsock), Homebrew cask | ~4 wks |
| **bench** | `ampoule-bench` (Python): boot / disk / CPU benchmarks → DuckDB/SQLite → analysis notebook. Later compares VZ vs. our engine | ~2–3 wks, alongside v0.2 |

### Engine track (starts after v0.2)

Each step is a demoable result and a good write-up ("I booted Linux on my own hypervisor").

| Milestone | Scope | Est. |
|-----------|-------|------|
| **E1 Hello, kernel** | Rust engine: VM memory, vCPU run loop, exit handling, PL011 UART, device tree. Boot a Linux kernel + initramfs to a serial shell | ~4–6 wks |
| **E2 Usable Linux** | In-kernel GIC (`hv_gic`), timers, PSCI (multi-core), virtio-mmio blk/net/console/rng/vsock | ~4–6 wks |
| **E3 UEFI** | EDK2 firmware, ACPI tables, PCIe (ECAM) + virtio-pci. Boot a stock Linux ISO through UEFI | ~6–8 wks |
| **E4 Windows boots** | NVMe, XHCI + USB keyboard/tablet, GOP framebuffer, TPM 2.0 (CRB + libtpms). Windows installer to desktop | ~8–12 wks |
| **E5 Usable Windows** | Networking, display in the Ampoule window (IOSurface), install flow + `autounattend.xml`, guest agent | ~6–8 wks |
| **1.0** | Polish, docs site, Apple Developer ID signing + notarization | ~3 wks |
| Stretch | GPU (Linux Venus → MoltenVK first), App Store build, Coherence, Python SDK | — |

- Rough calendar: v0.1 ≈ mid-Nov 2026, v0.2 + bench ≈ Jan 2027, Linux on our engine ≈ spring 2027, Windows ≈ late summer–fall 2027. Exams and interviews come first; slips are expected.
- v0.1–v0.2 releases are build-from-source / ad-hoc signed (the VZ and Hypervisor entitlements aren't restricted). Notarization ($99/yr Apple Developer Program) waits for 1.0.
- Escape hatch only: the backend protocol (D5) would let a temporary QEMU backend slot in if Windows were ever needed sooner.

## Non-goals (D17)

Never:
- Intel Macs.
- x86/x64 guest operating systems (Windows' Prism and Rosetta for Linux cover x86 apps).
- Hosts other than macOS; macOS older than 26.
- Container runtime / Docker replacement.
- Datacenter features: clusters, live migration, fleet management.
- macOS guests on our own engine (they stay on Virtualization.framework).
- Accounts, paid tiers, or telemetry that is on by default.

Not before 1.0: 3D GPU, Coherence, USB passthrough, the App Store build.

## Decisions

Each decision has a record in [`decisions/`](decisions/). This table is the index.

| # | Decision | Status |
|---|----------|--------|
| D1 | Guests: macOS, Linux (ARM64), **Windows 11 ARM64 is a 1.0 must-have** | Decided |
| D2 | Audience: both developers/CI (CLI, headless) and desktop users (GUI, integration) | Decided |
| D3 | Host minimum: **macOS 26** (native Liquid Glass, latest VZ APIs) | Decided |
| D4 | License: **Apache-2.0** for all Ampoule code, DCO sign-off for contributions | Decided |
| D5 | Pluggable `VMBackend`: VZ backend (macOS, light Linux) + Ampoule engine (Windows, full Linux) | Decided |
| D6 | **Own VM engine on Hypervisor.framework** for Windows. No QEMU | Decided |
| D7 | Distribution: **both** notarized DMG (+ Homebrew cask) and Mac App Store | Decided |
| D8 | Windows install: **both** bring-your-own ISO and guided download | Decided |
| D9 | GPU acceleration is a product goal; not a 1.0 blocker for dev workflows | Decided |
| D10 | Guest agent: Rust everywhere, host↔guest protocol defined as a schema | Decided |
| D11 | **Don't bundle a Python runtime.** Python lives in companions: SDK (`pip install ampoule`) and `ampoule-bench` | Decided |
| D12 | Purpose: a public portfolio project that demonstrates engineering rigor and transparent AI-assisted building | Decided |
| D13 | Maintained part-time (~6–8 h/week); milestones sized to fit | Decided |
| D14 | Engine language: **Rust**, running as a per-VM process controlled over a schema-defined socket API | Decided |
| D15 | Engine name: **`ampoule-engine`** | Decided |
| D16 | Project name: **Ampoule** (renamed from mVM: `tinylabscom/mvm` is an active Rust/HVF microVM project with the same name) | Decided |
| D17 | Non-goals list (above) | Decided |
| D18 | AI-assisted workflow: author designs/reviews, AI implements; ADRs, PR template, AI review log | Decided |

## License rationale (D4)

- Apache-2.0: permissive, explicit patent grant, enterprise-friendly, App Store-compatible.
- With QEMU out (D6), every likely dependency is permissive: rust-vmm crates (Apache-2.0/BSD-3), EDK2 (BSD-2-Clause-Patent), libtpms (BSD-3). libkrun and Cloud Hypervisor (Apache-2.0) are reference code.
- No GPL in the shipped app, so the App Store build has no license conflict.
- Not legal advice; sanity-check before first release.

## Backends

### VZ backend — macOS + lightweight Linux guests
- macOS: `VZMacOSRestoreImage` → IPSW install, paravirtualized Metal GPU, virtiofs automount. Max 2 concurrent (kernel-enforced).
  Stays on VZ permanently: macOS guests depend on Apple's private paravirtual devices.
- Linux: `VZEFIBootLoader`, virtio-gpu (2D only), Rosetta for x86 binaries, SPICE agent clipboard, nested virt on M3+.
- Snapshots: `saveMachineState`/`restoreMachineState` + APFS `clonefile` for disks.
- macOS 27 hosts add USB passthrough (`VZUSBPassthroughDevice`), EFI Secure Boot and custom virtio devices. Offer them behind `#available(macOS 27, *)`.

### Ampoule engine — Windows 11 ARM64 + full-featured Linux (D6, D14)
- Hypervisor.framework: `hv_vm_create`, `hv_vm_map`, `hv_vcpu_create`/`hv_vcpu_run`, in-kernel GICv3 via `hv_gic_create` (macOS 15+).
- Machine model: modeled on QEMU's `virt` layout so stock EDK2 (ArmVirtPkg) needs minimal changes. Windows needs ACPI (MADT, GTDT, SPCR, FADT, DSDT, MCFG, IORT), not device tree.
- **Lean on Windows' built-in drivers** to avoid shipping our own at first:
  - Storage: NVMe (inbox `stornvme`).
  - Input: XHCI + USB HID keyboard/tablet (inbox).
  - Display: UEFI GOP framebuffer → Windows Basic Display driver (inbox).
  - Network: to evaluate: virtio-net + virtio-win `netkvm` ARM64, or USB CDC-NCM over our XHCI (inbox `UsbNcm`).
  - TPM 2.0: CRB interface backed by libtpms.
- x86/x64 Windows apps run via Windows' own Prism emulation — no x86 guest emulation needed.
- Reference code: libkrun (Rust, HVF on macOS), Cloud Hypervisor (Rust, aarch64 + ACPI + EDK2), rust-vmm crates (`vm-memory`, `virtio-queue`, `acpi_tables`, `vm-fdt`).
- **GPU: hardest problem.** 1.0 = display-only framebuffer. 3D is a research track (D9).
- Note: Microsoft officially authorizes Windows 11 on Apple Silicon only via Parallels/VMware; it runs elsewhere but isn't "supported".

## Architecture

```
Ampoule.app (SwiftUI, Liquid Glass)        ampoule (CLI)
          \                            /
           AmpouleCore (Swift package: bundle format, config, backend protocol)
          /                            \
  VZ backend (per-VM XPC helper)     ampoule-engine (Rust, one process per VM)
                                       socket API (schema) + IOSurface framebuffer
                    \                  /
                guest agent over vsock (Rust)
        (clipboard, time sync, IP report, shutdown, later: Coherence)
```

- `.ampoule` bundle: `config.json` (versioned), disks (raw/ASIF), NVRAM/aux storage, hardware model, machine ID.
- One process per VM: crash isolation, headless mode, VMs survive app quit.
- One schema toolchain generates Swift + Rust bindings for both the engine API and the guest-agent protocol.

## Known gaps vs Parallels

- Coherence: needs guest agent + window streaming; per-guest-OS work.
- USB passthrough: in VZ on macOS 27+ hosts only; possible later in our engine (we already emulate XHCI).
- Bridged networking (VZ): restricted `com.apple.vm.networking` entitlement — NAT + userspace networking until granted. Our engine uses userspace networking.
- 3D GPU for Linux/Windows guests.

## Distribution (D7)

- Two build flavors from one codebase: `Direct` (DMG/Homebrew) and `AppStore` (sandboxed).
- App Store flavor: sandboxed, `ampoule-engine` embedded as a helper with sandbox inheritance; bridged networking likely Direct-only.

## Windows install (D8)

- BYO ISO: file picker, validate ARM64 image.
- Guided: fetch Microsoft's official ARM64 ISO.
- Both paths: generated `autounattend.xml` (local account, skip OOBE), guest agent auto-installed. Inbox drivers mean little or no driver injection.

## GPU roadmap (D9)

| Guest | Today | Path to 3D |
|-------|-------|------------|
| macOS | Paravirtualized Metal via VZ | Done |
| Linux | virtio-gpu 2D (VZ) | virtio-gpu **Venus** (Vulkan) → MoltenVK → Metal, Zink for GL, in our engine. Proven by libkrun/krunkit. |
| Windows | GOP framebuffer, WARP software D3D | No open path today. Needs a WDDM driver + host D3D→Metal translation. Multi-year effort. |

- Do Linux Venus first: it builds the host-side GPU infrastructure Windows would reuse.

## Guest agent (D10)

- Runs inside guests on 3 OSes: service install (Windows service / systemd / launchd), cross-compilation, binary size, signing, OS API access.
- Rust: one codebase, mature Win32 + Wayland/X11 crates, objc2 for macOS. Same language as the engine.
- The protocol schema matters more than the language — define it once, generate host (Swift) and guest (Rust) bindings.

## Open questions

- None blocking.
