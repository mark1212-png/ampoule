# 0023. Installing macOS guests

- Status: Proposed
- Date: 2026-10-06

## Context

macOS guests can't boot from an ISO. Virtualization.framework installs them from an Apple restore image (`.ipsw`, about 27 GB for macOS 27), which also fixes the VM's hardware model.

## Options

- **When to install:** as part of `create`, or as a separate `install` step on an existing bundle.
- **Where restore images come from:** a file the user supplies, Apple's "latest supported" catalog, or both.

## Decision

- macOS is installed during `ampoule create --os macos --ipsw <file|latest>`. The bundle is only moved into the library once installation succeeds, so a failed or cancelled install (Control-C) leaves nothing behind (decision 0020's staging, extended with a prepare step).
- `--ipsw latest` downloads the newest image this Mac supports into `~/Library/Caches/Ampoule/RestoreImages` and reuses it later. A download only gets its final name once its size matches what the server announced.
- `ampoule ipsw` shows the latest supported version and its URL without downloading.
- The VM's CPU and memory are checked against the restore image's minimums before installing.
- `vz.json` for a macOS VM stores the machine identifier, MAC address and hardware model. Unlike Linux, these are never created on first boot: a macOS bundle without them is reported as not installed.
- The CLI's root command stays synchronous: Virtualization.framework work must run on the main dispatch queue, which Swift's async entry point doesn't provide. Async steps run on the main actor while the CLI spins the main run loop.

## Consequences

Creating a macOS VM takes as long as the download plus installation. The app needs its own progress UI for this (next change). Apple limits a Mac to two running macOS VMs at once.

## Rationale

_To be written by the author._
