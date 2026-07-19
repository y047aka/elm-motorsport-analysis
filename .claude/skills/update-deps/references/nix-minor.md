# Nix (minor)

Update flake inputs to the latest commit within the current channel.

## Audit

Check pinned revision dates in flake.lock:

```bash
nix run .#deps-audit -- nix-flakelock-audit
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
