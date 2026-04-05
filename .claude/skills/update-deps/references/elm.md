# Elm

## Audit

Check `which elm-json` first. If unavailable, tell the user to run `direnv reload` or `nix develop`, then skip.

`elm-json upgrade` has no `--dry-run`. Report current pinned versions:

```bash
deno run --allow-read .claude/skills/update-deps/scripts/elm-versions-report.ts
```

## Update

Use `--yes` to skip interactive confirmation.

### CRITICAL — elm-pages ecosystem exclusion

`app/elm.json` contains `dillonkearns/*` packages that MUST stay in sync with the elm-pages npm package. Do NOT accept version changes to these packages. Always restore them unconditionally.

> To update `dillonkearns/*` packages, use `/update-deps elm-pages`. See `references/elm-pages.md` for details.

1. Capture dillonkearns package versions and restore commands:
   ```bash
   deno run --allow-read .claude/skills/update-deps/scripts/elm-dillonkearns-guard.ts
   ```
   Save the output (the `restore commands` section contains the commands needed in step 3).

2. Run `elm-json upgrade --yes app/elm.json`.

3. Restore dillonkearns packages by executing each command from the `restore commands` section of step 1's output.

### Other elm.json files

Upgrade normally:
```bash
elm-json upgrade --yes package/elm.json
elm-json upgrade --yes review/elm.json
```

## Verify

```bash
nix run .#test
nix run .#build
```
