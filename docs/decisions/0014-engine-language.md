# 0014. Engine written in Rust, one process per VM

- Status: Accepted
- Date: 2026-10-06

## Context

The best open-source reference hypervisors (Firecracker, Cloud Hypervisor, libkrun) are Rust.

## Decision

Write ampoule-engine in Rust. Run one engine process per VM, controlled over a schema-defined socket API.

## Consequences

A second language in the repo. Crash isolation and headless VMs come for free.

## Rationale

_To be written by the author._
