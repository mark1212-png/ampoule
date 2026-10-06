# 0022. App window and VM lifecycle

- Status: Proposed
- Date: 2026-10-06

## Context

The Mac app needs rules for what happens to a running VM when its window closes, when the app quits, and when a VM is removed.

## Options

- **Window close:** shut the VM down (like the CLI), or leave it running (like Parallels).
- **Quit:** cut power to all VMs, refuse to quit, or ask guests to shut down first.
- **Remove:** delete the bundle permanently, or move it to the Trash.

## Decision

- Closing a VM window leaves the VM running. The library marks it as running and offers "Show Window".
- Quitting asks every running guest to shut down and waits; guests still running after 30 seconds are forced off.
- "Move to Trash" moves a stopped VM's bundle to the Trash, where it can be recovered. Running VMs can't be removed.
- "Start from ISO…" attaches an installer for that run only, like `ampoule run --iso`.

## Consequences

VMs only run while the app is open. Running VMs after quit needs the per-VM helper process from DESIGN.md, planned for a later release.

## Rationale

_To be written by the author._
