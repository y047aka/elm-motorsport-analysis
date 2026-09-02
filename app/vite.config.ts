import { defineConfig, type Plugin } from "vite";
import elmPlugin from "vite-plugin-elm";
import {
  cpSync,
  createReadStream,
  existsSync,
  mkdirSync,
  statSync,
} from "node:fs";
import type { IncomingMessage, ServerResponse } from "node:http";
import { extname, join, resolve } from "node:path";

const staticDir = resolve(import.meta.dirname, "static");

const mimeTypes: Record<string, string> = {
  ".json": "application/json",
  ".jsonl": "application/jsonl",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".csv": "text/csv",
};

function sendFile(res: ServerResponse, filePath: string): boolean {
  if (!existsSync(filePath) || !statSync(filePath).isFile()) return false;
  const mime = mimeTypes[extname(filePath).toLowerCase()];
  if (mime) res.setHeader("Content-Type", mime);
  createReadStream(filePath).pipe(res);
  return true;
}

// What answers `/api` while no server is running. The rounds `cli-serve` reads
// out of the database are the rounds `cli-run` exported under `static/wec`, and
// one path is the other with its root replaced -- so the VRT and a dev session
// with no JVM see what the server would have sent.
function serveExport(req: IncomingMessage, res: ServerResponse): void {
  const urlPath = decodeURIComponent((req.url ?? "").split("?")[0]);
  const exported = urlPath.startsWith("/api/wec/")
    ? join(staticDir, "wec", urlPath.slice("/api/wec/".length))
    : "";
  if (exported.startsWith(staticDir) && sendFile(res, exported)) return;
  res.statusCode = 502;
  res.end("no API server, and nothing exported at this path");
}

// Serve (dev) and copy (build) the `static/` directory at `/static`, mirroring
// how elm-pages exposed it. It is kept outside `public/` so the paths the CLI
// writes under `static/` stay stable.
function staticAssets(): Plugin {
  return {
    name: "serve-static-dir",
    configureServer(server) {
      server.middlewares.use("/static", (req, res, next) => {
        const urlPath = decodeURIComponent((req.url ?? "").split("?")[0]);
        const filePath = join(staticDir, urlPath);
        if (filePath.startsWith(staticDir) && sendFile(res, filePath)) return;
        next();
      });
    },
    closeBundle() {
      if (!existsSync(staticDir)) return;
      const dist = resolve(import.meta.dirname, "dist");
      cpSync(staticDir, join(dist, "static"), { recursive: true });
      // The one URL the app asks for before it knows anything: a bundle with no
      // server behind it -- the Tauri build, a static host -- answers it with
      // the export's own calendar, whose rounds point back into `/static/wec`.
      mkdirSync(join(dist, "api/wec"), { recursive: true });
      cpSync(join(staticDir, "wec/index.json"), join(dist, "api/wec/index.json"));
    },
  };
}

export default defineConfig({
  // `@/*` is the import alias `components.json` names, so it has to resolve the
  // same way here as it does in `tsconfig.json` for `shadcn add` to write
  // imports this build can follow.
  resolve: { alias: { "@": resolve(import.meta.dirname, "src") } },
  // `debug: false` disables the Elm time-travel debugger overlay in dev so it
  // never appears in VRT screenshots. Production build still optimizes because
  // `vite build` sets NODE_ENV=production (optimize defaults to true then).
  plugins: [elmPlugin({ debug: false }), staticAssets()],
  publicDir: "public",
  server: {
    port: 1234,
    strictPort: true,
    proxy: {
      "/api": {
        target: "http://127.0.0.1:8080",
        configure(proxy) {
          proxy.on("error", (_error, req, res) =>
            serveExport(req, res as ServerResponse),
          );
        },
      },
    },
  },
  build: {
    outDir: "dist",
    emptyOutDir: true,
    rollupOptions: {
      onwarn(warning, warn) {
        // Base UI and whichever vendored components `shadcn add` writes a
        // "use client" onto carry one; nothing in this bundle reads the
        // directive, and Rollup reports every file that has one.
        if (warning.code === "MODULE_LEVEL_DIRECTIVE") return;
        warn(warning);
      },
    },
  },
});
