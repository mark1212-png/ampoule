# 0010. Guest agent in Rust with a shared protocol schema

- Status: Accepted
- Date: 2026-10-06

## Context

The agent runs inside three guest operating systems and needs native OS APIs.

## Decision

Write it in Rust. Define the host-guest protocol once as a schema and generate Swift and Rust bindings.

## Consequences

One codebase for the agent, the same language as the engine.

## Rationale

_To be written by the author._
