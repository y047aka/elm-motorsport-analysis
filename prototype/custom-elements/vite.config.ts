import { defineConfig } from "vite";
import { resolve } from "node:path";
import elmPlugin from "vite-plugin-elm";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  // `@/*` is the alias the app's `components.json` names, and the vendored
  // components import through it. Pointing at the app's `src` is what keeps
  // this prototype from carrying a second copy of them.
  resolve: {
    alias: { "@": resolve(import.meta.dirname, "../../app/src") },
    // Vite resolves a bare import against this project's root rather than the
    // importing file's, so `package.json` here has to carry everything the
    // app's components import even though nothing in `src/` imports it. And
    // what does resolve out of `app/node_modules` has to be pinned to one
    // copy, or Base UI calls hooks on a React that is not the one rendering.
    dedupe: ["react", "react-dom", "@base-ui/react"],
  },
  plugins: [elmPlugin({ debug: false }), tailwindcss()],
  esbuild: { jsx: "automatic" },
  server: { port: 1235, strictPort: true },
});
