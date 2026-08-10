# Rust (minor)

Semver-compatible (patch and minor) updates for Rust crates.

`app/src-tauri/Cargo.toml` is the repository's only Rust package — a standalone
Tauri v2 app, with no Cargo workspace above it.

## Audit

```bash
cargo update --dry-run --manifest-path app/src-tauri/Cargo.toml 2>&1 | nix run .#deps-audit -- rust-minor-audit
```

The script classifies semver-compatible updates into minor and patch sections.

## Update

```bash
cargo update --manifest-path app/src-tauri/Cargo.toml
```

## Verify

```bash
cargo check --manifest-path app/src-tauri/Cargo.toml
```
