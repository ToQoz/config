# Session Harness Runner Reference

This file is retained for backward compatibility. The runner skill has been
simplified — harnesses are now self-contained execution packages.

Run a harness with:

```bash
bash .session-harness/<task-slug>/run.sh
```

All loop mechanics, verification, and retry logic live in `run.sh` (copied from
the creator skill's `runtime/run.sh`). See the creator skill for documentation.
