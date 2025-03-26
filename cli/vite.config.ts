import { defineConfig } from 'vite'
import type { Plugin } from 'vite'
import elmPlugin from 'vite-plugin-elm'

export default defineConfig({
  build: {
    lib: {
      entry: 'src/index.ts',
      formats: ['cjs'],
      fileName: (format) => `index.${format}`
    },
    rollupOptions: {
      external: ['xhr2', 'prompts', 'fs'],
      output: {
        format: 'cjs',
        exports: 'auto'
      }
    },
    sourcemap: true,
    minify: 'esbuild'
  },
  plugins: [elmPlugin() as Plugin]
})
