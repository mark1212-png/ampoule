# Ampoule — notes for AI agents

Ampoule is an open-source VM app for Apple Silicon (macOS 26+): SwiftUI + Liquid Glass app, `ampoule` CLI,
AmpouleCore Swift package, and `ampoule-engine` (Rust, Hypervisor.framework). Read `docs/DESIGN.md` first.

## Roles

- The author designs, decides and reviews. You implement, test and draft docs.
- Never change the **Decision** or **Rationale** section of a record in `docs/decisions/`. Propose a new record instead.
- Never write in the author's voice: walkthroughs (`docs/walkthroughs/`) and ADR rationales are theirs.
  You may draft outlines or questions for them, clearly marked as drafts.

## Rules

- Every change goes through a branch and a pull request using `.github/pull_request_template.md`.
- Tests are required for new behavior. Run `swift test` and, for engine changes, `cargo fmt --check && cargo clippy -- -D warnings && cargo test` in `engine/`.
- Fail closed: invalid configuration or unexpected state is an error, never a silent default.
- No new dependency without a decision record.
- No GPL code linked into shipped binaries (decision 0004).
- Stay inside the non-goals in `docs/DESIGN.md`.
- Commits you write end with the `Co-Authored-By` trailer. Use `git commit -s`.

## Wording (README, release notes, docs)

- The author is an "independent developer", never "founder".
- Say "shipped" or "released" only for a tagged public release.
- Be accurate about who did what: the author designed and reviewed; AI agents implemented.

## Layout

- `Sources/AmpouleCore` — bundle format, configuration, `VMBackend` protocol
- `Sources/AmpouleCLI` — `ampoule` command-line tool
- `App/` + `Ampoule.xcodeproj` — the Mac app
- `engine/` — Rust workspace for `ampoule-engine`
- `docs/` — design, decision records, walkthroughs, AI review log
