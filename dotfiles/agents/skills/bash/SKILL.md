---
name: bash
description: Best practices for writing safe and correct Bash commands. Use this skill whenever constructing Bash commands — especially when handling file paths with shell-special characters (e.g. Next.js `[]`/`()` routes, Remix `$` params), building pipelines, or writing shell snippets that will be executed by tools.
user-invocable: false
---

# Bash

## Special Characters in File Paths

File paths in modern web frameworks often contain characters that the shell interprets specially. Passing them unquoted to Bash commands causes silent failures, glob expansion, or errors.

## The Rule

Always single-quote file paths in Bash commands when the path contains any of these characters:

| Character | Shell interprets as |
|-----------|-------------------|
| `[` `]`   | Glob character class |
| `(` `)`   | Subshell / grouping |
| `$`       | Variable expansion |
| `*` `?`   | Glob wildcards |
| `&` `;`   | Command separators |
| `#`       | Comment |

Single quotes prevent all shell interpretation — the path is passed literally.

## Examples

**Next.js** — dynamic route segments use `[param]` and route groups use `(group)`:

```bash
# Wrong — shell tries to glob-expand the brackets
cat app/(main)/users/[userId]/page.tsx

# Correct
cat 'app/(main)/users/[userId]/page.tsx'
```

**Remix** — file-based routes use `$` for params and `.` as separators:

```bash
# Wrong — shell expands $userId as a variable
cat app/routes/users.$userId.tsx

# Correct
cat 'app/routes/users.$userId.tsx'
```

## Scope

This applies to every Bash tool call that takes a file path argument: `cat`, `cp`, `mv`, `rm`, `head`, `tail`, `wc`, `grep`, `sed`, `awk`, compiler/linter CLIs, etc.

When in doubt, single-quote. It never hurts a path that has no special characters, and it prevents hard-to-debug failures for paths that do.
