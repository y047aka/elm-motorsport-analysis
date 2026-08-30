import { defineConfig } from "vite";
import { resolve } from "node:path";
import elmPlugin from "vite-plugin-elm";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  // `@/*` is the alias the app's `components.json` names. The probe reaches
  // the app's own `ReactElement` through it, so what is measured here is the
  // lifecycle the app ships.
  resolve: {
    alias: { "@": resolve(import.meta.dirname, "../../app/src") },
    // Vite resolves a bare import against this project's root rather than the
    // importing file's, so `react-dom/client` inside the app's file resolves
    // out of this project -- which is why `package.json` here carries React
    // even though nothing under `src/` imports it directly.
    dedupe: ["react", "react-dom"],
  },
  plugins: [elmPlugin({ debug: false }), tailwindcss()],
  esbuild: { jsx: "automatic" },
  server: { port: 1235, strictPort: true },
});
