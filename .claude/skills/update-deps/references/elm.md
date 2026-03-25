# Elm

## Audit

Check `which elm-json` first. If unavailable, tell the user to run `direnv reload` or `nix develop`, then skip.

`elm-json upgrade` has no `--dry-run`. Read the elm.json files (`app/elm.json`, `package/elm.json`, `review/elm.json`) and report pinned versions.

## Update

Use `--yes` to skip interactive confirmation.

### CRITICAL — elm-pages ecosystem exclusion

`app/elm.json` contains `dillonkearns/*` packages that MUST stay in sync with the elm-pages npm package. Do NOT accept version changes to these packages. Always restore them unconditionally:

1. Read `app/elm.json` and record ALL `dillonkearns/*` package versions (direct and indirect).
2. Run `elm-json upgrade --yes app/elm.json`.
3. Restore all `dillonkearns/*` packages to recorded versions. Run one install per package:
   ```bash
   elm-json install --yes 'dillonkearns/elm-pages@10.2.1' -- app/elm.json
   elm-json install --yes 'dillonkearns/elm-form@3.0.1' -- app/elm.json
   # ... repeat for each dillonkearns/* package
   ```

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
