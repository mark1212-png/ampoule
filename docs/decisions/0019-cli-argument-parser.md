# 0019. Use swift-argument-parser for the CLI

- Status: Proposed
- Date: 2026-10-06

## Context

The `ampoule` CLI is growing subcommands (`create`, `list`, `validate`, soon `run`) with options, help text and validation. Hand-written argument parsing gets error-prone quickly.

## Options

- **swift-argument-parser** (Apple, Apache-2.0): declarative subcommands, generated help, shell completions. Widely used.
- **Hand-written parsing**: no dependency, but every option, error message and help screen is our code to maintain and test.

## Decision

Use swift-argument-parser in the `AmpouleCLI` target only. AmpouleCore stays dependency-free.

## Consequences

One external dependency, pinned in `Package.resolved`. License-compatible with decision 0004.

## Rationale

_To be written by the author._
