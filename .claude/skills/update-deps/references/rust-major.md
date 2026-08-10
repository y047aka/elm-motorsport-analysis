# Rust (major)

Major version updates for Rust crates (leftmost non-zero version component increases).

`app/src-tauri/Cargo.toml` is the repository's only Rust package — a standalone
Tauri v2 app, with no Cargo workspace above it.

## Audit

```bash
nix run .#deps-audit -- rust-major-audit
```

The script parses all Cargo.toml files, runs `cargo search` for each crate, and classifies results. A **major bump** is when the leftmost non-zero version component increases (e.g., `0.8 → 0.9`, `1.x → 2.x`). Focus on the `major updates` section.

## Update

For each crate with a confirmed major version bump, update its version
constraint in `app/src-tauri/Cargo.toml` (`[dependencies]` and
`[build-dependencies]`). `tauri` and `tauri-build` are released together and
must move as a pair.

Then re-resolve:

```bash
cargo update --manifest-path app/src-tauri/Cargo.toml
```

## Verify

```bash
cargo check --manifest-path app/src-tauri/Cargo.toml
```
