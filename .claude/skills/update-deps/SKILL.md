---
name: update-deps
description: Audit and update all project dependencies (npm, Elm, Rust/Cargo, Nix flake).
argument-hint: "[npm|elm|rust|nix]"
disable-model-invocation: true
allowed-tools:
  - Bash(npm outdated *)
  - Bash(npm update *)
  - Bash(npm install *)
  - Bash(elm-json *)
  - Bash(cargo update *)
  - Bash(nix flake update *)
  - Bash(nix run *)
  - Bash(git diff *)
  - Bash(git status *)
  - Bash(git add *)
  - Bash(git commit *)
  - Bash(which *)
  - Bash(cat flake.lock *)
  - Bash(python3 *)
  - Read
  - Grep
  - Glob
---

# Update Dependencies

Audit and update project dependencies across all ecosystems in this monorepo.

## Instructions

### Phase 0: Pre-flight

Run `git status --short`. If there are uncommitted changes, warn the user and suggest committing or stashing first.

If `$ARGUMENTS` specifies an ecosystem (`npm`, `elm`, `rust`, or `nix`), only process that one. Otherwise, process all four.

### Phase 1: Audit

Run audit commands for each target ecosystem. Do NOT make any changes yet.

**npm:**
```bash
npm outdated || true
```
Note whether each update is a patch, minor, or major bump.

**Elm:**
Check `which elm-json` first. If unavailable, tell the user to run `direnv reload` or `nix develop`, then skip.

`elm-json upgrade` has no `--dry-run`. Read the elm.json files (`app/elm.json`, `package/elm.json`, `review/elm.json`) and report pinned versions.

**Rust:**
```bash
cargo update --dry-run --manifest-path cli/Cargo.toml
```

**Nix:**
No dry-run available. Report pinned revision dates from `flake.lock`:
```bash
cat flake.lock | python3 -c "
import json, sys, datetime
d = json.load(sys.stdin)
for k, v in d.get('nodes', {}).items():
    if 'locked' in v:
        ts = v['locked'].get('lastModified', 0)
        date = datetime.datetime.fromtimestamp(ts).strftime('%Y-%m-%d')
        rev = v['locked'].get('rev', '?')[:12]
        print(f'{k}: pinned {date} (rev {rev})')
"
```

Present the results as a consolidated report.

### Phase 2: Update

- **Single ecosystem** (`$ARGUMENTS` given) — ask yes/no confirmation.
- **All ecosystems** (no argument) — ask which to update. Accept: `all`, comma-separated list, or `skip`.

**npm:**
Run `npm update` for semver-compatible updates. For major bumps that exceed the semver range, list them separately and ask if the user wants `npm install <pkg>@latest`.

**Elm:**
Use `--yes` to skip interactive confirmation.

**CRITICAL — elm-pages ecosystem exclusion:** `app/elm.json` contains `dillonkearns/*` packages that MUST stay in sync with the elm-pages npm package. Do NOT accept version changes to these packages. Always restore them unconditionally:

1. Read `app/elm.json` and record ALL `dillonkearns/*` package versions (direct and indirect).
2. Run `elm-json upgrade --yes app/elm.json`.
3. Restore all `dillonkearns/*` packages to recorded versions. Run one install per package:
   ```bash
   elm-json install --yes 'dillonkearns/elm-pages@10.2.1' -- app/elm.json
   elm-json install --yes 'dillonkearns/elm-form@3.0.1' -- app/elm.json
   # ... repeat for each dillonkearns/* package
   ```

Other elm.json files — upgrade normally:
```bash
elm-json upgrade --yes package/elm.json
elm-json upgrade --yes review/elm.json
```

**Rust:**
```bash
cargo update --manifest-path cli/Cargo.toml
```

**Nix:**
```bash
nix flake update
```

### Phase 3: Verify

| Updated ecosystem | Verification commands |
|---|---|
| npm | `nix run .#test`, `nix run .#build` |
| Elm | `nix run .#test`, `nix run .#build` |
| Rust | `nix run .#cli-test` |
| Nix | `nix run .#test`, `nix run .#cli-test`, `nix run .#build` |

Show `git diff --stat` so the user can see what changed.

### Phase 4: Commit (optional)

Ask the user if they want to commit. If yes, follow the repository's commit message conventions (check `git log --oneline`).

## Special handling

- **Playwright version change**: If `@playwright/test` is updated, remind the user to run `npx playwright install` and warn that VRT snapshots may need updating via `nix run .#test-vrt`.
- **Network errors**: If any audit command fails, report the error and continue with the remaining ecosystems.
