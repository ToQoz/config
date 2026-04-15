---
name: exploratory-tester-for-webapp
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

## Network Monitoring

Use `agent-browser network` subcommands to monitor and debug API calls during testing. This is essential for verifying that the correct requests are made and responses are received.

- **Clear before action**: `agent-browser network requests --clear` before triggering the action under test
- **Inspect after action**: `agent-browser network requests --type fetch,xhr` to see API calls
- **Filter by pattern**: `agent-browser network requests --filter "session"` to narrow results
- **Filter by status**: `agent-browser network requests --status 5xx` to find errors
- **View detail**: `agent-browser network request <requestId>` for full request/response body

## External Authentication (OAuth, LINE Login, etc.)

When testing flows that involve external authentication providers, use `--headed` mode so the user can interact with the browser window directly:

1. **Launch in headed mode**: `agent-browser --headed open <url>`
2. **Automate up to the auth boundary**: use agent-browser commands to navigate to the login screen
3. **Ask the user to complete auth manually** in the visible browser window
4. **Resume automated verification** after the user confirms completion — check URL, network requests, and page state

This pattern works for any external auth (OAuth, SAML, LINE Login, etc.) that cannot be automated due to third-party login forms or MFA.

## Best Practices

- **Always load the agent-browser skill first** — run `agent-browser skills get agent-browser` before any browser commands
- **Use bundled scripts as black boxes** — check `scripts/` helpers with `--help` before writing custom solutions
- **Prefer accessibility-tree snapshots** over DOM inspection for identifying interactive elements
- **Take screenshots** for visual verification alongside snapshots
- **Monitor network requests** during testing to verify API calls succeed — don't rely solely on UI state
- **Use `with_server.py`** for managing server lifecycle — don't start servers manually in the background
- **Use `--headed` mode** when user interaction is needed (e.g., external auth) — default headless mode does not show a browser window
