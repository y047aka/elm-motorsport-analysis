# Elm

## Audit

Check `which elm-json` first. If unavailable, tell the user to run `direnv reload` or `nix develop`, then skip.

`elm-json upgrade` has no `--dry-run`. Report current pinned versions:

```bash
nix run .#deps-audit -- elm-versions-report
```

## Update

Use `--yes` to skip interactive confirmation.

### CRITICAL — elm-pages ecosystem exclusion

`app/elm.json` contains `dillonkearns/*` packages that MUST stay in sync with the elm-pages npm package. Do NOT accept version changes to these packages. Always restore them unconditionally.

> To update `dillonkearns/*` packages, use `/update-deps elm-pages`. See `references/elm-pages.md` for details.

1. Capture dillonkearns package versions and restore commands:
   ```bash
   nix run .#deps-audit -- elm-pages-elm-guard
   ```
   Save the output (the `restore commands` section contains the commands needed in step 3).

2. Run `elm-json upgrade --yes app/elm.json`.

3. Run `elm-json upgrade --unsafe --yes app/elm.json`. The `--unsafe` flag is required to detect and install major version updates; without it only semver-compatible updates are applied.

4. Restore dillonkearns packages by executing each command from the `restore commands` section of step 1's output. This applies to changes made by both the normal and `--unsafe` runs.

### Other elm.json files

Upgrade normally, then check majors with `--unsafe`:
```bash
elm-json upgrade --yes package/elm.json
elm-json upgrade --unsafe --yes package/elm.json
```

## Verify

```bash
nix run .#test
nix run .#build
```
