# Changelog

## 0.1.0 — unreleased

First release: macOS and Linux guests through Virtualization.framework, from a Mac app or the `ampoule` CLI.

### Added

- **VM bundles** (`<name>.ampoule`): `config.json` plus a sparse disk, created all-or-nothing, with an exclusive lock while running. Broken bundles are listed with the reason ([#1](https://github.com/mark1212-png/ampoule/pull/1)).
- **Linux guests:** EFI boot, virtio disk/network/graphics, installer ISOs attached for one run; stable machine identity stored in `vz.json` ([#2](https://github.com/mark1212-png/ampoule/pull/2)).
- **Mac app:** library window, VM windows with Shut Down and Force Off, new-VM sheet, Move to Trash ([#3](https://github.com/mark1212-png/ampoule/pull/3)).
- **macOS guests:** installed from Apple's restore image during `create`, with `--ipsw latest` downloading and caching the newest supported version; `ampoule ipsw` ([#4](https://github.com/mark1212-png/ampoule/pull/4)).
- **macOS VMs from the app,** installing in the background with progress and Cancel ([#5](https://github.com/mark1212-png/ampoule/pull/5)).
- **Shared folders** for macOS and Linux guests (virtiofs), from the CLI and the app ([#6](https://github.com/mark1212-png/ampoule/pull/6)).
- **Tests:** 59 unit tests, including the app's model, plus `scripts/smoke-test.sh`, which boots a real VM ([#7](https://github.com/mark1212-png/ampoule/pull/7)).

### Verified by hand (macOS 27.0.1 host, Apple Silicon)

- Alpine Linux 3.24 boots from its ISO to a login prompt; a second `run` of the same VM is refused.
- macOS 27.0.1 downloads (26.6 GB), installs in about 3 minutes, and boots to Setup Assistant.
- A VM boots with a shared folder attached; editing it while running is refused.
- The smoke test passes.

### Not yet verified

- Mounting a shared folder inside a guest.
- Clicking through the app: Start, the new-VM sheet, background installs, the Shared Folders card, quitting with a running VM. (Automated clicking needs Accessibility access, which the test setup doesn't have.)
