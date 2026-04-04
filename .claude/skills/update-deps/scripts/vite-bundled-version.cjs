// Print the vite version bundled inside elm-pages.
// Checks the nested copy first; falls back to the hoisted copy when npm deduplicates.
// Run from the project root.
const fs = require("fs");
const path = require("path");
const root = process.cwd();
const nested = path.join(root, "node_modules/elm-pages/node_modules/vite/package.json");
const hoisted = path.join(root, "node_modules/vite/package.json");
const pkg = fs.existsSync(nested) ? nested : hoisted;
console.log(require(pkg).version);
