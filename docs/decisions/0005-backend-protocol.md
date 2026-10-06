# 0005. Pluggable VM backends

- Status: Accepted
- Date: 2026-10-06

## Context

No single macOS virtualization API covers all three guest operating systems well.

## Decision

Define a `VMBackend` protocol in AmpouleCore. Two implementations: Virtualization.framework (macOS, light Linux) and ampoule-engine (Windows, full Linux).

## Consequences

The app and CLI never talk to a backend directly. Backend-specific features need capability flags.

## Rationale

_To be written by the author._
