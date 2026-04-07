// Print the vite version bundled inside elm-pages.
// Checks the nested copy first; falls back to the hoisted copy when npm deduplicates.
// Run from the project root.

function existsSync(path: string): boolean {
  try {
    Deno.statSync(path);
    return true;
  } catch {
    return false;
  }
}

const root = Deno.cwd();
const nested = `${root}/node_modules/elm-pages/node_modules/vite/package.json`;
const hoisted = `${root}/node_modules/vite/package.json`;
const pkg = existsSync(nested) ? nested : hoisted;
console.log(JSON.parse(Deno.readTextFileSync(pkg)).version);
