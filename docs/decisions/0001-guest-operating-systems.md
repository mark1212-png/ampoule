# 0001. Supported guest operating systems

- Status: Accepted
- Date: 2026-10-06

## Context

Ampoule aims to replace Parallels Desktop on Apple Silicon. Parallels users run macOS, Linux and Windows.

## Decision

Support macOS, ARM64 Linux and Windows 11 ARM64 guests. Windows is required for 1.0.

## Consequences

Windows cannot be served well by Virtualization.framework, so a second backend is needed (see 0005, 0006).

## Rationale

_To be written by the author._
