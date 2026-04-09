# Rust (minor)

Semver-compatible (patch and minor) updates for Rust crates.

The workspace root is `cli/Cargo.toml` with members `cli/` and `motorsport/`.

## Audit

```bash
cargo update --dry-run --manifest-path cli/Cargo.toml 2>&1 | cargo run --manifest-path .claude/skills/update-deps/scripts/Cargo.toml -- rust-minor-audit
```

The script classifies semver-compatible updates into minor and patch sections.

## Update

```bash
cargo update --manifest-path cli/Cargo.toml
```

## Verify

```bash
nix run .#cli-test
```
