# 0007. Distribution: direct download and Mac App Store

- Status: Accepted
- Date: 2026-10-06

## Context

Developers expect Homebrew; many desktop users expect the App Store.

## Decision

Ship both: a notarized DMG plus Homebrew cask, and a sandboxed App Store build.

## Consequences

Two build flavors. Bridged networking is likely direct-download only. The App Store build is deferred until after 1.0.

## Rationale

_To be written by the author._
