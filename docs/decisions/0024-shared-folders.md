# 0024. Shared folders

- Status: Proposed
- Date: 2026-10-06

## Context

Sharing folders between the Mac and a VM is a core Parallels feature and part of the v0.1 roadmap. Virtualization.framework provides virtiofs devices for both macOS and Linux guests.

## Options

- **One virtiofs device per folder**, each with its own tag, or **one device exposing all folders by name**.
- **Where the setting lives:** `config.json`, or a separate file.
- **Editing:** any time (applied on next boot), or only while the VM is stopped.

## Decision

- Shared folders are stored in `config.json` as absolute paths with a read-only flag. Bundles without the field decode as sharing nothing, which shares less, never more.
- One virtiofs device exposes every folder under its own name. macOS guests use Apple's automount tag and see `/Volumes/My Shared Files`; Linux guests mount the `ampoule` tag.
- Folder names must be unique, because the guest sees folders by name. Paths must be absolute and not `/`.
- Settings are only edited while the VM is stopped: `VMBundle.updatingConfiguration` takes the bundle lock and replaces `config.json` atomically. A VM's name, system and disks can't be changed this way.
- A shared folder that no longer exists stops the VM from starting, with an error naming the folder.
- CLI: `ampoule share add|remove|list`. App: a Shared Folders card in the VM's detail panel.

## Consequences

Paths are stored as plain strings, which works because the direct-download app isn't sandboxed. The App Store build will need security-scoped bookmarks instead.

## Rationale

_To be written by the author._
