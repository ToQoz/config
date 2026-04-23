---
name: docx-text-extraction
description: Extract text content from .docx files, including tracked changes (red-line edits). Use this skill whenever the user wants to read, analyze, or extract content from Word documents — even if they just say "read this docx" or "what changed in this document". Runs via `nix run nixpkgs#pandoc` so nothing needs to be installed globally.
---

## Overview

Extract text and tracked changes from `.docx` files using pandoc via Nix. No global installs required.

## Commands

### Plain text extraction

```bash
nix run nixpkgs#pandoc -- document.docx -o output.md
```

### With tracked changes (insertions/deletions visible)

```bash
nix run nixpkgs#pandoc -- --track-changes=all document.docx -o output.md
```

Tracked changes appear as:
- `[text]{.insertion author="..." date="..."}` — inserted text
- `[text]{.deletion author="..." date="..."}` — deleted text
- `[]{.paragraph-insertion ...}` / `[]{.paragraph-deletion ...}` — paragraph-level changes

### Accept all changes (clean output)

```bash
nix run nixpkgs#pandoc -- --track-changes=accept document.docx -o output.md
```

### Reject all changes (original text only)

```bash
nix run nixpkgs#pandoc -- --track-changes=reject document.docx -o output.md
```

## Tips

- When the user provides a docx with "red text" or "tracked changes", use `--track-changes=all` to identify what changed.
- Compare the `--track-changes=accept` output against the project's current content to determine what needs updating.
- For docx files without tracked changes (e.g., images of pages provided separately), convert to images or read the docx directly and diff manually against the existing content.
