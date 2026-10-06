# Ampoule

An open-source virtual machine app for Apple Silicon Macs. Run macOS, Linux and Windows 11 guests in a native SwiftUI app with Liquid Glass, or from the command line.

> **Status: pre-alpha.** Nothing is usable yet. This repository currently holds the design, decision records and project skeleton. See the [roadmap](docs/DESIGN.md#roadmap-68-hweek).

## What it will do

- **macOS and Linux guests** through Apple's Virtualization.framework (first release, v0.1).
- **Windows 11 ARM64** through `ampoule-engine`, our own VM engine written in Rust on Hypervisor.framework.
- **A native Mac app** (SwiftUI, Liquid Glass) and an **`ampoule` CLI** for scripting and CI, sharing one core.
- Shared folders, snapshots, clipboard sharing and a guest agent.

What it will not do is listed under [Non-goals](docs/DESIGN.md#non-goals-d17).

## Architecture

```
Ampoule.app (SwiftUI)              ampoule (CLI)
          \                        /
           AmpouleCore (Swift package: bundle format, config, backend protocol)
          /                        \
  Virtualization.framework        ampoule-engine (Rust, one process per VM)
  (macOS, Linux)                  (Windows, full-featured Linux)
```

Details: [docs/DESIGN.md](docs/DESIGN.md). Every decision has a record in [docs/decisions](docs/decisions/).

## Building from source

Requirements: an Apple Silicon Mac, macOS 26 or later, Xcode 26 or later. Rust (via [rustup](https://rustup.rs)) for the engine.

```bash
scripts/build-cli.sh            # builds and signs the ampoule CLI, prints its path
swift test                      # unit tests
xcodebuild -project Ampoule.xcodeproj -scheme Ampoule build
cd engine && cargo test         # ampoule-engine
```

The CLI must be signed with the virtualization entitlement to start VMs; `scripts/build-cli.sh` does that.

## Trying it

```bash
ampoule create Ubuntu --os linux --disk 64
ampoule run Ubuntu --iso ~/Downloads/ubuntu-server-arm64.iso   # install from an ARM64 ISO
ampoule run Ubuntu                                             # later boots
ampoule list
```

VMs live in `~/Library/Application Support/Ampoule/VMs` (override with `$AMPOULE_HOME`).

## How this was built

Ampoule is built by one independent developer working with AI coding agents (Claude). The split is deliberate and recorded:

- **The author** makes the design decisions, writes the rationale in each [decision record](docs/decisions/), reviews every change before it merges, and writes a [walkthrough](docs/walkthroughs/) of the code for each milestone.
- **AI agents** write most of the implementation, tests and first drafts of documentation. Their commits carry a `Co-Authored-By` trailer, so `git log` shows who wrote what.
- **Corrections** to AI-written code are logged in the [AI review log](docs/ai-review/), with a category and severity for each.

## License

[Apache-2.0](LICENSE). Contributions are accepted under the [Developer Certificate of Origin](CONTRIBUTING.md#sign-off).
