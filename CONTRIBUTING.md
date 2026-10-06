# Contributing

Thanks for your interest. Ampoule is maintained part-time (about 6–8 hours a week), so reviews may take a while.

## Before you start

- Check the [non-goals](docs/DESIGN.md#non-goals-d17). Pull requests for those will be closed.
- For anything larger than a bug fix, open an issue first.
- New dependencies and architecture changes need a [decision record](docs/decisions/template.md).

## Pull requests

- One topic per pull request. Fill in the template, including how the change was verified.
- Tests are required for new behavior. `swift test` and `cargo test` must pass.
- Run `scripts/smoke-test.sh` before opening a pull request that touches VM startup. It boots a real VM, which GitHub's runners can't do.
- If an AI tool wrote part of the change, say so in the template. That's welcome, not penalized.

## Sign-off

Every commit must be signed off under the [Developer Certificate of Origin](https://developercertificate.org):

```bash
git commit -s
```

This adds a `Signed-off-by:` line certifying you have the right to submit the change under the project license.
