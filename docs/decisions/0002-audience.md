# 0002. Audience: developers and desktop users

- Status: Accepted
- Date: 2026-10-06

## Context

Developers and CI need scripting and headless VMs; desktop users need a polished GUI and integration.

## Decision

Serve both. Every feature is reachable from the CLI and the app, built on one shared core.

## Consequences

The CLI exists from v0.1. Per-VM processes are needed so VMs can run headless.

## Rationale

_To be written by the author._
