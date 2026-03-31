# Troubleshooting

## `idtool verify <profile>` reports a missing launcher

Create it again:

```bash
idtool launcher create <profile>
```

## `idtool verify <profile>` reports a missing session file

Create a session entry again:

```bash
idtool session create <profile> --scope system
```

or:

```bash
idtool session create <profile> --scope user
```

## A managed link was replaced by a real directory

Repair all recorded links:

```bash
idtool links repair <profile>
```

## Install fails halfway through

This version should roll the profile back automatically. After that, inspect:

```text
~/.local/share/isolated-desktops/profiles/<name>/logs/
~/.local/share/isolated-desktops/profiles/<name>/reports/
```

Then run:

```bash
idtool analyze <profile>
idtool verify <profile>
```

## I removed a profile by mistake

List trash:

```bash
idtool trash list
```

Restore it:

```bash
idtool trash restore <trash-entry>
```

## The editor workspace does not open

Check which editor command exists:

- `codium`
- `code`
- `vscodium`
- `xdg-open`

Then recreate the workspace:

```bash
idtool workspace create <profile>
idtool workspace open <profile>
```

## Session starts but does not behave like the upstream project

That usually means the adapter or manifest needs work, or the upstream installer touched host-wide state. Compare:

- `manifest` values
- adapter logic
- generated profile home
- upstream install expectations

## A profile refuses to install because it is locked

Another install, update, remove, or links operation is probably still running for that profile. Wait for it to finish or clean up the stale lock after confirming nothing is still running.
