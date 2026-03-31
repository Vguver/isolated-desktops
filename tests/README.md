# Tests

These are lightweight repository validation scripts.

Files:

- `manifests.sh` - checks that manifest JSON files are valid
- `smoke.sh` - runs the main local happy-path workflow in temporary state directories
- `install_resilience.sh` - covers clone failure, disk-space guard, interrupted install rollback, and lock contention
- `lifecycle.sh` - covers install, update, verify, workspace, and completion installation
- `shellcheck.sh` - runs `shellcheck` if it is available
- `run-all.sh` - runs the lightweight check sequence

Run all checks with:

```bash
./tests/run-all.sh
```

These tests are intentionally lightweight. They do not replace real end-to-end testing of upstream desktop installers on a live host.
