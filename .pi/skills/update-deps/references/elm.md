# Elm

No minor/major split: one flow, majors included.

## Audit

`elm-json upgrade` has no `--dry-run`. Report the pinned versions instead:

```bash
nix run .#deps-audit -- elm-versions-report
```

`elm-json` comes from the dev shell: reach it as
`nix develop --command elm-json ...`, or skip the ecosystem's update with a
note if it is missing.

## Update

```bash
elm-json upgrade --yes app/elm.json
elm-json upgrade --unsafe --yes app/elm.json

elm-json upgrade --yes package/elm.json
elm-json upgrade --unsafe --yes package/elm.json
```

`--unsafe` is what detects and installs majors; without it only
semver-compatible updates apply.

## Verify

```bash
nix run .#test
nix run .#build
```
