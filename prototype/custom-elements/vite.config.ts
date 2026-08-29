import { defineConfig } from "vite";
import elmPlugin from "vite-plugin-elm";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [elmPlugin({ debug: false }), tailwindcss()],
  esbuild: { jsx: "automatic" },
  server: { port: 1235, strictPort: true },
});
