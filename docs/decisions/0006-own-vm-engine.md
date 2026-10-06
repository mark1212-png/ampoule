# 0006. Own VM engine on Hypervisor.framework

- Status: Accepted
- Date: 2026-10-06

## Context

Options for Windows were QEMU with HVF acceleration (fast to ship, GPL) or our own engine (slower, full control).

## Decision

Build our own engine on Hypervisor.framework. No QEMU.

## Consequences

Windows support moves to roughly late 2027. No GPL in the app. GPU acceleration becomes possible later because we own the device model.

## Rationale

_To be written by the author._
