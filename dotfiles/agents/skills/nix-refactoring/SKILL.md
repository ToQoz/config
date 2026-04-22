---
name: nix-refactoring
description: Small-step refactoring of Nix flake / Home Manager / nix-darwin / NixOS configurations, verified by derivation-hash comparison before applying anything to the system. Use this whenever splitting a large module into smaller ones, relocating declarations between modules, renaming files, reorganizing imports, or any other structural change where behavior should stay the same. Trigger phrases include "refactor home.nix", "split this flake", "reorganize nix modules", "extract X into its own module", and "move X to Y.nix". Prefer this skill over ad-hoc edits whenever a Nix refactor has an explicit "don't change behavior" constraint.
---

# nix-refactoring

## Intent

Refactor Nix configurations in small, reversible steps, each one verified to produce an identical derivation (or an intentionally different derivation with an identical closure) before it is committed. The system is never rebuilt during the loop — verification is purely from evaluation.

## When To Use

- Splitting a large `home.nix` / `configuration.nix` / `flake.nix` into multiple files
- Moving declarations (`programs.*`, `home.packages`, activation scripts) between modules
- Renaming files or reorganizing the directory layout under `home-manager/`, `modules/`, `nixos/`, `darwin/`
- Promoting a let-binding, overlay, or derivation to a separate file
- Any refactor with a "preserve behavior" constraint where a build is expensive or unsafe to repeat

## Why This Works

Nix evaluation is pure: the top-level derivation (`.drv`) hash captures every input that would affect the build output. If the `.drv` hash is unchanged, the resulting system is bit-identical — no build, no activation required to prove equivalence.

When the `.drv` hash changes, `nix-diff` can pinpoint exactly which input or environment variable differs, which is usually enough to identify whether the change is semantically meaningful.

## Workflow

### 1. Identify the top-level attribute

Pick the attribute that represents the whole system or home configuration. Examples:

- nix-darwin: `.#darwinConfigurations.<hostname>.system`
- NixOS: `.#nixosConfigurations.<hostname>.config.system.build.toplevel`
- Home Manager standalone: `.#homeConfigurations.<user>.activationPackage`

### 2. Capture the baseline

```
nix path-info --derivation '.#<attr>' > /tmp/drv-before
```

This is the single source of truth for "what the system looks like now". Do not rebuild; the derivation path alone is enough.

### 3. Make one small change

Examples of "small": extract one `programs.foo` block into its own file, move one package from list A to list B, rename one let-binding. If the change touches multiple concerns, split it further.

For flakes, **always** `git add` new files before re-evaluating — flakes only see tracked files, and an untracked new module will surface as a confusing evaluation error.

### 4. Re-evaluate and compare

```
nix path-info --derivation '.#<attr>' > /tmp/drv-after
diff /tmp/drv-before /tmp/drv-after && echo "OK: identical"
```

Identical → the refactor preserves behavior. Commit.

Different → proceed to diagnosis (section below).

### 5. Commit

One commit per verified small step. Keep the commit message descriptive of the refactor's intent, not a summary of diff. A good tag: `refactor(home-manager): extract foo.nix`.

### 6. Repeat

Each commit is a fresh baseline for the next step. If something later breaks, `git bisect` locates the offending commit in O(log n) and each commit is independently verified.

## Handling a Changed Derivation

Not every `.drv` change means the refactor is wrong. Classify the change before reacting:

### Unintentional change — investigate and fix

Example: splitting a module reorders a `lib.mkMerge` list. Semantically equivalent, but the `.drv` sees it as different, and it usually signals a real risk (order can matter for wrapper args, PATH, init scripts, etc.). Fix it to keep the `.drv` identical, so the refactor stays provably behavior-preserving.

### Intentional change — verify closure equivalence instead

Example: moving `pkgs.tmux` from one module to another, where list order in `home.packages` is semantically irrelevant but the derivation list still reorders. Accept the `.drv` change but prove that the set of installed store paths is unchanged.

Closure equivalence check:

```
extract_pkgs() {
  nix derivation show --recursive "$1" 2>/dev/null \
    | jq -r '[..|.pkgs? // empty] | .[] | fromjson | .[] | .paths[]' \
    | sort -u
}

comm -3 <(extract_pkgs /tmp/drv-before-str) <(extract_pkgs /tmp/drv-after-str)
```

Empty output → same store paths in both configurations, just in different positions in the list. Commit with a note in the message explaining which property was verified and why the `.drv` difference is acceptable.

## Common Pitfalls (Module Merge Order)

When a declaration is moved from an inlined module into an imported submodule, the Nix module system merges values across modules in **module evaluation order within the same priority**. A declaration that appeared in one specific position when inlined may merge at a different position when imported — and because this is invisible in the source diff, it can surprise.

The three recurring shapes:

### List concatenation — e.g. `home.packages`, `extraWrapperArgs`

Home Manager or NixOS program modules may contribute internally to the same list. The user's split-out list may merge before those internal contributions instead of after.

Fix: `lib.mkAfter` on the user's list to push it to priority 1500.

```nix
home.packages = lib.mkAfter [ pkgs.foo pkgs.bar ];
```

### Line/text concatenation — e.g. `programs.zsh.initContent`

The target module may assign specific `mkOrder` values to named sections (e.g. HM's zsh module uses 510–1200 for internal chunks). The user's default-priority (1000) content may be placed differently from where it ended up when inlined.

Fix: `lib.mkOrder <N>` with a value between the adjacent section priorities. Read the target module's source to find the right number.

```nix
initContent = lib.mkOrder 1050 ''...'';
```

### Attribute set merging

Usually harmless — attrsets merge as unions. But the same `mkOrder` logic applies to overridden values within attrsets. Watch for `mkForce`/`mkDefault` cross-module interactions if the `.drv` diff points here.

## Diagnosis Tools

```
# Structured derivation diff (shows exactly which inputs/envs differ)
nix run nixpkgs#nix-diff -- $(cat /tmp/drv-before) $(cat /tmp/drv-after)

# Package-level closure diff (what was added/removed/changed)
nix run nixpkgs#nvd -- diff $(cat /tmp/drv-before) $(cat /tmp/drv-after)

# Inspect a specific env var in the derivation
nix derivation show --recursive '.#<attr>' \
  | jq -r '[..|.wrapperArgs? // empty]'
```

`nix-diff` is usually the first stop — it highlights "The environments do not match" with a per-variable delta. If the delta is only in a list-typed env var and the set of items is the same, the change is order-only.

## Anti-Patterns

- Making a multi-module refactor in one commit, then trying to diff — noise overwhelms signal. Always one small change per commit.
- Rebuilding the system (`darwin-rebuild switch`, `nixos-rebuild switch`) as the verification step — slow, invasive, and still cannot confirm equivalence without a prior snapshot. Use derivation hash comparison instead.
- Adding `lib.mkAfter` / `lib.mkOrder` prophylactically to every moved declaration — these fixes are only justified when the `.drv` diff actually shows a merge-order issue. Over-applying them adds noise and couples the module to priority internals it doesn't need.
- Accepting a changed `.drv` without at least the closure check — "it probably still builds" is not verification.
- Using `git add -A` after adding new files — on flakes this is necessary for visibility, but it can accidentally stage unrelated work. Prefer explicit `git add <path>`.

## Quick Reference Commands

```
# Baseline
nix path-info --derivation '.#darwinConfigurations.<host>.system' > /tmp/drv-before

# After each change
git add <new-files>  # flakes require tracked files
nix path-info --derivation '.#darwinConfigurations.<host>.system' > /tmp/drv-after
diff /tmp/drv-before /tmp/drv-after && echo "OK: identical"

# Diagnose a diff
nix run nixpkgs#nix-diff -- $(cat /tmp/drv-before) $(cat /tmp/drv-after)

# Promote to next baseline
cp /tmp/drv-after /tmp/drv-before
```
