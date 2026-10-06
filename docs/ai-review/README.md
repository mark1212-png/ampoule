# AI review log

A running record of every correction the author makes to AI-written code before it merges.
It shows where AI agents needed human judgment on this project, and lets the author measure it.

## Process

1. While reviewing a pull request, note each problem you fix in AI-written code.
2. Add one row per problem to [log.csv](log.csv).
3. Label the pull request `ai-corrected`.

## Columns

| Column | Meaning |
|--------|---------|
| `date` | Date of the review (YYYY-MM-DD) |
| `pr` | Pull request number |
| `component` | `core`, `cli`, `app`, `engine`, `agent`, `docs`, `ci` |
| `category` | See rubric below |
| `severity` | `minor` (style, clarity), `major` (wrong behavior), `critical` (security, data loss, crash) |
| `caught_by` | `review`, `test`, `ci`, `runtime` |
| `description` | One sentence: what was wrong and what you changed |

## Category rubric

| Category | Use when the AI… |
|----------|------------------|
| `logic-bug` | wrote code that does the wrong thing |
| `wrong-api` | used a real API incorrectly or a deprecated one |
| `invented-api` | called an API, flag or option that doesn't exist |
| `overengineered` | added unnecessary abstraction, options or code |
| `missing-test` | left behavior untested or wrote tests that don't test it |
| `security` | introduced unsafe handling of guest input, memory, files or permissions |
| `spec-drift` | ignored a decision record, non-goal or the request |
| `docs` | wrote inaccurate or misleading documentation |
