# 0020. VM bundle format and library location

- Status: Proposed
- Date: 2026-10-06

## Context

Every VM needs a self-contained home on disk that the app, the CLI and both backends agree on.

## Options

- **One directory per VM** (`<name>.ampoule/`) holding `config.json` and disks, like Parallels' `.pvm` and Tart's VM directories.
- **A central database** plus loose disk files: harder to back up, move or inspect.

## Decision

- A VM is a `<name>.ampoule` directory: `config.json` (schema version 1) plus disk images, with disk paths relative to the bundle.
- The library is `~/Library/Application Support/Ampoule/VMs`, overridable with `$AMPOULE_HOME`.
- Disks are created as sparse raw files, so a 64 GiB disk takes no space until the guest writes to it.
- Creation is atomic: the bundle is built in a hidden staging directory and moved into place, so failures leave nothing behind.
- Broken bundles are reported, never skipped; `ampoule list` exits with status 2 when any bundle is invalid.

## Consequences

Bundles can be copied, backed up or deleted in Finder. Backend-specific files (for example Virtualization.framework's EFI variable store) will live inside the bundle too. The App Store build (decision 0007) will need a different library location inside its sandbox container.

## Rationale

_To be written by the author._
