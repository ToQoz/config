---
name: nodejs-package-manager
description: Determines which Node.js package manager to use for a project. Use this skill whenever you're about to run install, add, remove, or any other package manager command in a Node.js project — even if the user just says "install the deps" or "add this package". Always check lock files before running any package manager command.
user-invocable: false
---

# Node.js Package Manager Selection

Before running any package manager command, detect which package manager the project uses by checking for lock files in the project root.

## Detection Rules

Check for lock files in this order:

| Lock file           | Package manager |
|---------------------|-----------------|
| `pnpm-lock.yaml`    | pnpm            |
| `yarn.lock`         | yarn            |
| `package-lock.json` | npm             |
| `bun.lockb`         | Bun             |
| *(none found)*      | pnpm (default)  |

```bash
# Quick detection
ls pnpm-lock.yaml yarn.lock package-lock.json bun.lockb 2>/dev/null | head -1
```

If multiple lock files exist (which is unusual and suggests a misconfiguration), prefer in the order listed above and note the ambiguity to the user.
