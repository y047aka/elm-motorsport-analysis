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

- The frontend loads unchanged: `/static/**` assets resolve same-origin under
  `tauri://localhost`, so no extra CSP or permissions are required.
- Icons are placeholders — replace before distribution.
- `"csp": null` in `tauri.conf.json` should be tightened before release.
