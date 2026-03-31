# Contributing

Thanks for helping improve `isolated-desktops`.

## Ground rules

- keep comments and documentation in English
- prefer small, reviewable commits
- do not describe profile isolation as full system isolation
- do not silently ignore failures that matter to users

## Development checks

Run these before opening a pull request:

```bash
./tests/run-all.sh
```

## Shell style

- use `set -euo pipefail`
- quote variable expansions unless you intentionally need word splitting
- prefer shared helpers from `scripts/lib/` over duplicating logic
- use semantic exit helpers from `scripts/lib/common.sh`

## Adding a new desktop

1. add a manifest under `manifests/`
2. add or update an adapter under `scripts/adapters/`
3. validate the manifest with `./tests/manifests.sh`
4. document any special host impact in the manifest notes

## Pull request notes

A good pull request should include:

- what changed
- why it changed
- how it was tested
- whether it affects profile state, host state, or docs
