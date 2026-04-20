---
name: github-pr-images
description: Attach images (screenshots, diagrams, recordings) to a GitHub PR body from the CLI by uploading them as a prerelease asset and emitting Markdown image links. Use whenever the user wants to add screenshots to a PR description, embed images in a PR, put an image in a PR body, or attach a picture/diagram to a pull request — even if they don't mention "prerelease" or the exact mechanism. Also use for updating the images on an existing PR and for cleaning up the image storage after merge.
---

# github-pr-images

GitHub has no official API for attaching images to a PR body. The Web UI
drag-and-drop uses a private endpoint backed by the browser session cookie,
and `gh` upstream has declined to support it. This skill uses a **prerelease
as image storage** instead — it relies only on public `gh` commands, keeps
assets inside the repository's visibility boundary, and works in CI.

## When to use

- The user wants to add screenshots, diagrams, GIFs, or any image to a PR body
- The user has image files locally and wants them rendered in the PR
- The user wants to refresh or replace images already attached to a PR
- The user wants to clean up image storage after a PR is merged

Skip this skill if the user explicitly prefers Web UI drag-and-drop — it
produces nicer `user-attachments/assets` URLs but cannot be done from CLI.

## Prerequisites

- `gh` CLI authenticated against the target repo
- Running inside a git clone of the target repo (for `gh repo view`), or the
  user supplies `--repo OWNER/NAME`
- An existing PR on the target repo (image upload is indexed by PR number)

## Tag convention

Each PR gets a dedicated prerelease tagged `pr-<PR_NUMBER>-images`. Using a
PR-scoped tag means re-running the upload for the same PR updates the same
release rather than creating clutter, and cleanup after merge deletes exactly
one release.

## Workflow

### 1. Gather inputs

Identify:

- `PR_NUMBER` — the PR the images belong to. Ask the user if not given.
- `IMAGES` — absolute or relative paths to the image files. Glob expansion is
  the caller's responsibility; resolve globs before calling `gh`.
- `REPO` — `OWNER/NAME`. Resolve with:

  ```bash
  gh repo view --json nameWithOwner -q .nameWithOwner
  ```

Verify every image path exists before touching GitHub — a missing file mid-
upload leaves a half-populated release.

### 2. Upload images to the prerelease

Try `release create` first; if the release already exists, fall back to
`release upload --clobber` so the script is idempotent:

```bash
TAG="pr-${PR_NUMBER}-images"

gh release create "$TAG" "${IMAGES[@]}" \
  --title "PR #${PR_NUMBER} screenshots" \
  --notes "Image assets for PR #${PR_NUMBER}. Auto-generated." \
  --prerelease 2>/dev/null \
  || gh release upload "$TAG" "${IMAGES[@]}" --clobber
```

`--prerelease` keeps these releases out of the normal release list on the
repo homepage. `--clobber` overwrites existing assets that share a filename
(useful when regenerating a screenshot with the same name).

### 3. Emit Markdown

For each uploaded image, fetch its `browser_download_url` from the release
and print a Markdown image tag:

```bash
for f in "${IMAGES[@]}"; do
  name=$(basename "$f")
  url=$(gh api "repos/${REPO}/releases/tags/${TAG}" \
    --jq ".assets[] | select(.name==\"${name}\") | .browser_download_url")
  printf '![%s](%s)\n' "$name" "$url"
done
```

Print the Markdown to stdout so the user can pipe to `pbcopy`, redirect to a
file, or inspect before using. Do not auto-edit the PR body unless the user
explicitly asks — the user usually wants to choose where in the body the
images appear.

### 4. Insert into PR body (only if requested)

If the user asks to update the PR body, read the current body, insert the
generated Markdown at an appropriate location (usually under a "Screenshots"
heading if one exists, otherwise append), and write it back:

```bash
gh pr view "$PR_NUMBER" --json body --jq '.body' > /tmp/pr-body.md
# edit /tmp/pr-body.md to include the Markdown block
gh pr edit "$PR_NUMBER" --body-file /tmp/pr-body.md
```

When replacing a previously-inserted block, prefer matching a stable marker
(e.g., a `<!-- pr-images:start -->` ... `<!-- pr-images:end -->` pair)
rather than doing loose text substitution that could mangle user edits.

### 5. Verify

Confirm one of the printed URLs actually renders:

```bash
curl -sIL "<first-url>" | head -n 1
```

A `200 OK` (after redirects) means the prerelease is public enough to embed.
For private repos, the URL is only visible to users with repo read access —
that is the intended behavior.

## Cleanup after merge

When the PR merges, remove both the prerelease and its tag:

```bash
gh release delete "pr-${PR_NUMBER}-images" --cleanup-tag --yes
```

Offer to do this automatically if the user has just merged the PR in the
same session. `--cleanup-tag` removes the git tag so the repo's tag list
stays clean.

## Why this technique

- Only documented `gh` commands, so it does not rely on endpoints GitHub
  might remove without notice.
- Images stay inside the repo's visibility boundary — no public gist, no
  third-party host. Private-repo screenshots remain private.
- Works in CI with `GITHUB_TOKEN`; no browser cookie required.
- `--cleanup-tag` on delete leaves no trace after merge.
- Zero dependencies beyond `gh`.

## Alternatives worth knowing

- **GitHub Web UI drag-and-drop** — easiest for a one-off, produces the
  nicer `user-attachments/assets` URL. Not usable from CLI.
- **`gh extension install atani/gh-attach --mode release`** — wraps the
  same prerelease pattern as an installable extension.
- **Avoid** `drogers0/gh-image` (feeds `user_session` cookie to a private
  endpoint) and external hosts like Gist or Imgur (leaks internal captures).

## References

- https://mareksuppa.com/til/github-pr-images-from-cli/
- https://zenn.dev/atani/articles/gh-attach-github-image-upload
- https://github.com/cli/cli/issues/1895
