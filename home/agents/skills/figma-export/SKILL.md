---
name: figma-export
description: Export a Figma node to PNG, JPG, SVG, or PDF via the Figma REST API with an explicit scale factor. Use this whenever the user wants Figma export automation, asks for 2x/3x exports, wants node URL or node id based asset export, or needs repo-scoped Figma token handling through macOS Keychain instead of the built-in MCP screenshot flow.
---

# Figma Export

Use this skill when the user wants a real Figma export with `format` and `scale`, not just an MCP screenshot.

This skill wraps the Figma REST API `GET /v1/images/:key` through a local CLI:

- Script: `scripts/figma-export-cli`
  - Run the script from this skill's directory.
- Auth storage: macOS Keychain
- Auth scope: one token per project

## What to collect

Prefer a Figma node URL. The CLI can parse both:

- file key
- node id

If the user only gives a node id, also collect the file key.

## Project-scoped auth

The CLI stores one Figma token per project in macOS Keychain.

- Project scope is the current git root when inside a git repository.
- Otherwise project scope is the current working directory.

If no token exists for the current project, do not try to authenticate inside `export`.
Instead, tell the user to run the auth command themselves from the target project directory:

```bash
cd /path/to/project
/absolute/path/to/home/agents/skills/figma-export/scripts/figma-export-cli auth
```

The auth command reads the token from stdin without echoing it.

## Commands

Export from a full Figma URL:

```bash
./scripts/figma-export-cli export \
  --node 'https://www.figma.com/design/FILE_KEY/File-Name?node-id=1-2' \
  --format png \
  --scale 2 \
  --output ./tmp/frame@2x.png
```

Export from file key + node id:

```bash
./scripts/figma-export-cli export \
  --file-key FILE_KEY \
  --node 1:2 \
  --format svg \
  --output ./tmp/frame.svg
```

Manage auth explicitly:

```bash
./scripts/figma-export-cli auth
```

Other auth commands:

```bash
./scripts/figma-export-cli auth status
./scripts/figma-export-cli auth clear
```

## Execution rules

1. Prefer `export` with an explicit `--output` path so the destination is obvious.
2. If auth is required, stop and ask the user to run `cd <project>; <skill dir>/scripts/figma-export-cli auth`.
3. If the API returns an auth, permission, render, or missing-node error, stop and show the exact error to the user.
4. Do not silently fall back to `get_screenshot`.
5. Do not invent file keys or node ids.

## Error handling

When export fails, leave the decision to the user. Report:

- the exact command
- the API or CLI error
- whether the failure looks like auth, permissions, invalid node, or non-renderable content

Do not retry with guessed parameters unless the user asks.
