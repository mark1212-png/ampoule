# 0021. Virtualization.framework Linux machine

- Status: Proposed
- Date: 2026-10-06

## Context

The first backend boots Linux guests through Virtualization.framework (decision 0005). It needs a fixed virtual hardware set, a stable machine identity, and protection against running one VM twice.

## Options

- **Boot:** EFI firmware (`VZEFIBootLoader`), which boots standard installer ISOs, or direct kernel boot (`VZLinuxBootLoader`), which needs a separately supplied kernel and initrd.
- **Identity:** regenerate the machine identifier and MAC address each boot, or store them in the bundle.

## Decision

- **Boot** with EFI. The variable store lives in `efi-variables.bin` inside the bundle.
- **Hardware:** virtio block disks, NAT networking, virtio graphics (1920×1200, resized to the window), USB keyboard and pointer, entropy and memory balloon devices.
- **Installer ISOs** attach read-only as a USB drive for one run (`ampoule run --iso`); they're never written into `config.json`.
- **Identity:** the machine identifier and MAC address are created once and stored in `vz.json`. A damaged `vz.json` is an error, never regenerated, so the guest never silently sees new hardware.
- **Locking:** a running VM holds an exclusive `flock` on `<bundle>/.lock`, so the same VM can't be started twice.
- **Stopping:** closing the window or pressing Control-C asks the guest to shut down; a second request forces it off.
- **Signing:** Virtualization.framework requires the `com.apple.security.virtualization` entitlement, so the CLI is built with `scripts/build-cli.sh`, which signs it. Configuration validation also needs the entitlement, so unit tests check the built configuration and the signed CLI validates at run time.

## Consequences

macOS guests need a different platform and boot loader and come in a later change. macOS 27 adds USB passthrough, EFI Secure Boot and custom virtio devices to Virtualization.framework; those can be offered on macOS 27 hosts behind availability checks.

## Rationale

_To be written by the author._
