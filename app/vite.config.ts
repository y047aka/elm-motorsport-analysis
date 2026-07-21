import { defineConfig, type Plugin } from "vite";
import elmPlugin from "vite-plugin-elm";
import { cpSync, createReadStream, existsSync, statSync } from "node:fs";
import { extname, join, resolve } from "node:path";

const staticDir = resolve(import.meta.dirname, "static");

const mimeTypes: Record<string, string> = {
  ".json": "application/json",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".csv": "text/csv",
};

// Serve (dev) and copy (build) the `static/` directory at `/static`, mirroring
// how elm-pages exposed it. It is kept outside `public/` so the Rust CLI paths
// under `static/` stay stable.
function staticAssets(): Plugin {
  return {
    name: "serve-static-dir",
    configureServer(server) {
      server.middlewares.use("/static", (req, res, next) => {
        const urlPath = decodeURIComponent((req.url ?? "").split("?")[0]);
        const filePath = join(staticDir, urlPath);
        if (
          filePath.startsWith(staticDir) &&
          existsSync(filePath) &&
          statSync(filePath).isFile()
        ) {
          const mime = mimeTypes[extname(filePath).toLowerCase()];
          if (mime) res.setHeader("Content-Type", mime);
          createReadStream(filePath).pipe(res);
        } else {
          next();
        }
      });
    },
    closeBundle() {
      if (existsSync(staticDir)) {
        cpSync(staticDir, resolve(import.meta.dirname, "dist/static"), {
          recursive: true,
        });
      }
    },
  };
}

export default defineConfig({
  // `debug: false` disables the Elm time-travel debugger overlay in dev so it
  // never appears in VRT screenshots. Production build still optimizes because
  // `vite build` sets NODE_ENV=production (optimize defaults to true then).
  plugins: [elmPlugin({ debug: false }), staticAssets()],
  publicDir: "public",
  server: { port: 1234, strictPort: true },
  build: { outDir: "dist", emptyOutDir: true },
});
