import { defineConfig } from "vite";

export default {
  vite: defineConfig({}),
  headTagsTemplate(context) {
    return `
<link href="https://cdn.jsdelivr.net/npm/daisyui@5" rel="stylesheet" type="text/css" />
<link rel="stylesheet" href="/style.css" />
<link rel="stylesheet" href="/output.css" />
<meta name="generator" content="elm-pages v${context.cliVersion}" />
`;
  },
  preloadTagForFile(file) {
    // add preload directives for JS assets and font assets, etc., skip for CSS files
    // this function will be called with each file that is processed by Vite, including any files in your headTagsTemplate in your config
    return !file.endsWith(".css");
  },
};
