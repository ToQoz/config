---
name: webapp-acceptance-checks
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

## Test Records

Save all test artifacts and a detailed action log under `./.agents/cache/testing/YYYYMMDD-<short-title>/`.

- **Create the directory** at the start of a testing session (e.g., `./.agents/cache/testing/20260415-line-login-flow/`)
- **Screenshots**: save every screenshot there instead of `/tmp` (e.g., `01-init-page.png`, `02-tos-checked.png`, …). Use zero-padded sequential prefixes to preserve order.
- **Action log (`log.md`)**: record each step as it happens — action performed, observed result, and pass/fail. Include the screenshot filename on each step so the log and images cross-reference. Example:

  ```markdown
  ## 1. Open /mini/init
  - Action: `agent-browser open http://localhost:4001/mini/init`
  - Screenshot: 01-init-page.png
  - Result: Logo, TOS checkbox (unchecked), disabled button displayed. **OK**

  ## 2. Check TOS checkbox
  - Action: `agent-browser check @e1`
  - Screenshot: 02-tos-checked.png
  - Result: Button enabled. **OK**
  ```

- **Summary (`summary.md`)**: at the end of the session, write a result table (test item / result / notes) and list any bugs found.
- **Network logs**: when API failures are relevant, paste the filtered `agent-browser network requests` output into the action log step. **Mask sensitive values** (tokens, passwords, session IDs, cookies, API keys) — replace them with `***` or `<REDACTED>` before writing to the log.
- **Visibility for reviewers**: after testing, leave a record of what was tested and the results in the PR description or commit message so reviewers can confirm what was verified.

## Screenshots for PRs and reviewers

Screenshots that look broken to a reviewer waste their time even when the
underlying app is fine. A few rules to avoid that:

- **Default to viewport-fit screenshots** (`agent-browser screenshot path.png`).
  This matches what a reviewer sees if they open the page themselves.
- **Avoid `--full` unless you specifically need the full scroll height in one
  image.** On responsive layouts where a fixed sidebar, header, or root
  container stretches to the viewport, `--full` can produce an oversized
  canvas with the actual UI rendered in a small corner. The screenshot
  *looks* like a layout bug even when the live page renders correctly.
- **Always read back the saved image before linking it from a PR.** Use the
  Read tool to view PNGs; re-take without `--full` if the image shows large
  blank regions, a tiny clamped UI, or other render artifacts. This
  verification step is non-optional — broken-looking screenshots in a PR
  body will be flagged by the reviewer.
- **Long lists / tables** that legitimately need full scroll capture are the
  one case `--full` is appropriate; even then, sanity-check the result.
- **Set the viewport explicitly** (`agent-browser open ...` after closing
  any prior session) when you suspect the daemon is using a non-standard
  size; e.g. a previously-opened headed session can leave the viewport
  oversized.

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

## Element Selection Priority

When identifying elements to interact with, prefer queries that reflect **what the user sees and how they interact with the page**. Fall back to implementation details only when semantic queries are insufficient.

**Priority order (highest to lowest):**

1. **Role + accessible name** — buttons, links, headings, form controls by their ARIA role and label (e.g., the button labeled "Submit", the link "Sign in")
2. **Label text** — form fields by their associated `<label>` text
3. **Visible text content** — elements by the text they display
4. **Placeholder / alt text** — when no better semantic handle exists
5. **id / class / data attributes** — last resort when the above do not uniquely identify the element

This order matters because semantic queries are resilient to refactors (class renames, markup restructuring) and verify that the UI is actually accessible. If you find yourself reaching for `id` or `class`, pause and check whether a role or text query would work first.

## Best Practices

- **Always load the agent-browser skill first** — run `agent-browser skills get agent-browser` before any browser commands
- **Use bundled scripts as black boxes** — check `scripts/` helpers with `--help` before writing custom solutions
- **Prefer accessibility-tree snapshots** over DOM inspection for identifying interactive elements
- **Take screenshots** for visual verification alongside snapshots
- **Monitor network requests** during testing to verify API calls succeed — don't rely solely on UI state
- **Use `with_server.py`** for managing server lifecycle — don't start servers manually in the background
- **Use `--headed` mode** when user interaction is needed (e.g., external auth) — default headless mode does not show a browser window
