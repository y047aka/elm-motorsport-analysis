# Rust (minor)

Semver-compatible (patch and minor) updates for Rust crates.

The workspace root is `cli/Cargo.toml` with members `cli/` and `motorsport/`.

## Audit

```bash
cargo update --dry-run --manifest-path cli/Cargo.toml
```

Note whether each update is a patch or minor bump.

## Update

```bash
cargo update --manifest-path cli/Cargo.toml
```

## Verify

```bash
nix run .#cli-test
```
