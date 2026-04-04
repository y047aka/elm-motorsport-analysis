# Nix (minor)

Update flake inputs to the latest commit within the current channel.

## Audit

Check pinned revision dates in flake.lock:

```bash
node .claude/skills/update-deps/scripts/nix-flakelock-audit.cjs
```

## Update

```bash
nix flake update
```

## Verify

```bash
nix run .#test
nix run .#cli-test
nix run .#build
```
