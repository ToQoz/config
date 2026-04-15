---
name: webapp-adhoc-testing
description: Toolkit for interacting with and testing local web applications using agent-browser. Supports verifying frontend functionality, debugging UI behavior, capturing browser screenshots, and viewing browser logs.
allowed-tools: Bash(agent-browser:*), Bash(npx agent-browser:*)
---

# Web Application Testing

Test local web applications using **agent-browser** for browser automation.

**You must run `agent-browser skills get agent-browser` before running any agent-browser commands.** This file does not contain agent-browser command syntax. That content is served by the CLI and changes between versions.

**Helper Scripts Available**:
- `scripts/with_server.py` - Manages server lifecycle (supports multiple servers)

**Always run scripts with `--help` first** to see usage. DO NOT read the source until you try running the script first and find that a customized solution is absolutely necessary.

## Decision Tree: Choosing Your Approach

```
User task -> Is it static HTML?
    +- Yes -> Read HTML file directly to identify selectors
    |         +- Success -> Use agent-browser with file:// URL
    |         +- Fails/Incomplete -> Treat as dynamic (below)
    |
    +- No (dynamic webapp) -> Is the server already running?
        +- No -> Run: python scripts/with_server.py --help
        |        Then use the helper to start server + run agent-browser
        |
        +- Yes -> Reconnaissance-then-action:
            1. Navigate and snapshot the accessibility tree
            2. Take screenshot for visual reference
            3. Identify element refs from the snapshot
            4. Execute actions with discovered refs
```

## Using with_server.py

Start a server and run agent-browser commands after the server is ready:

**Single server:**
```bash
python scripts/with_server.py --server "npm run dev" --port 5173 -- \
  agent-browser open http://localhost:5173
```

**Multiple servers (e.g., backend + frontend):**
```bash
python scripts/with_server.py \
  --server "cd backend && python server.py" --port 3000 \
  --server "cd frontend && npm run dev" --port 5173 \
  -- agent-browser open http://localhost:5173
```

## Reconnaissance-Then-Action Pattern

1. **Load the skill first**:
   ```bash
   agent-browser skills get agent-browser
   ```

2. **Navigate and inspect** - use agent-browser to open the URL, take a snapshot (accessibility tree), and screenshot

3. **Identify element refs** from the accessibility tree snapshot

4. **Execute actions** using the discovered element refs

## Best Practices

- **Always load the agent-browser skill first** — run `agent-browser skills get agent-browser` before any browser commands
- **Use bundled scripts as black boxes** — check `scripts/` helpers with `--help` before writing custom solutions
- **Prefer accessibility-tree snapshots** over DOM inspection for identifying interactive elements
- **Take screenshots** for visual verification alongside snapshots
- **Use `with_server.py`** for managing server lifecycle — don't start servers manually in the background
- **Delegate unresolvable steps to the user** — when encountering OAuth or other external-provider authentication that the agent cannot complete, ask the user to perform those steps and resume testing after confirmation
