# Tauri (native app)

Tauri v2 shell that packages the Elm SPA frontend as a native desktop app.

## Develop

```bash
nix run .#tauri-dev      # runs `pnpm run start` (Vite dev, :1234) in a WebView
```

## Build

```bash
nix run .#tauri-build    # bundles app/dist into a native .app / .dmg
```

Run `cargo tauri icon icons/icon.png` once to (re)generate icons. Only the
desktop icons (`icon.icns` / `icon.ico` / `*.png`) are tracked; the rest are
git-ignored.

## Notes

- A bundle serves its assets over http on port 1430 rather than from
  `tauri://localhost`, which Elm cannot read as a location; a dev build opens
  the Vite server instead. `src/lib.rs` has the rest.
- The frontend loads unchanged: `/static/**` assets resolve same-origin with
  the page, so no extra CSP or permissions are required.
- Icons are placeholders — replace before distribution.
- `"csp": null` in `tauri.conf.json` should be tightened before release.
