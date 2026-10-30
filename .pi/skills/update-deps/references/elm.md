# Elm

## Audit

Check `which elm-json` first. If unavailable, run the audit through
`nix develop --command`, or tell the user to enter `nix develop`, then skip.

`elm-json upgrade` has no `--dry-run`. Report current pinned versions:

```bash
nix run .#deps-audit -- elm-versions-report
```

## Update

Use `--yes` to skip interactive confirmation.

Upgrade normally, then check majors with `--unsafe`. The `--unsafe` flag is required to detect and install major version updates; without it only semver-compatible updates are applied.

```bash
elm-json upgrade --yes app/elm.json
elm-json upgrade --unsafe --yes app/elm.json

elm-json upgrade --yes package/elm.json
elm-json upgrade --unsafe --yes package/elm.json
```

## Verify

```bash
nix run .#test
nix run .#build
```
