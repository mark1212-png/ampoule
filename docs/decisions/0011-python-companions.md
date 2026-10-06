# 0011. No bundled Python; Python companions instead

- Status: Accepted
- Date: 2026-10-06

## Context

Bundling a Python runtime adds size, signing work and sandbox issues, and nothing in the app needs it.

## Decision

Do not bundle Python. Python lives in companion projects: `ampoule-bench` and later a Python SDK.

## Consequences

The app stays Swift and Rust only.

## Rationale

_To be written by the author._
