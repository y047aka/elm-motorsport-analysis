// Classify npm outdated --json output into minor/major update sections.
// Pipe from: npm outdated --json 2>/dev/null | deno run --allow-read <this-script>
// Run from the project root.
import fs from "node:fs";
import path from "node:path";

function readStdin(): string {
  const chunks: Uint8Array[] = [];
  const buf = new Uint8Array(4096);
  for (;;) {
    const n = Deno.stdin.readSync(buf);
    if (n === null) break;
    chunks.push(buf.slice(0, n));
  }
  const merged = new Uint8Array(chunks.reduce((s, c) => s + c.length, 0));
  let offset = 0;
  for (const c of chunks) { merged.set(c, offset); offset += c.length; }
  return new TextDecoder().decode(merged);
}

interface OutdatedInfo {
  current: string;
  wanted: string;
  latest: string;
  dependent?: string;
}

const input = readStdin().trim();
if (!input) {
  console.log("--- minor updates ---");
  console.log("none");
  console.log("");
  console.log("--- major updates ---");
  console.log("none");
  process.exit(0);
}

const data: Record<string, OutdatedInfo> = JSON.parse(input);
const minor: string[] = [];
const major: string[] = [];
let playwrightChanged = false;
let viteEntry: { current: string; latest: string } | null = null;

for (const [name, info] of Object.entries(data)) {
  const current = info.current;
  const wanted = info.wanted;
  const latest = info.latest;
  const dep = info.dependent || "";

  if (current !== wanted) {
    minor.push(name + ": " + current + " -> " + wanted + " (" + dep + ")");
  }

  const currentMajor = parseInt(current);
  const latestMajor = parseInt(latest);
  if (latestMajor > currentMajor) {
    major.push(name + ": " + current + " -> " + latest + " (" + dep + ")");
  }

  if (name === "@playwright/test" && (current !== wanted || latestMajor > currentMajor)) {
    playwrightChanged = true;
  }

  if (name === "vite") {
    viteEntry = { current: current, latest: latest };
  }
}

console.log("--- minor updates ---");
console.log(minor.length ? minor.join("\n") : "none");
console.log("");
console.log("--- major updates ---");
console.log(major.length ? major.join("\n") : "none");
console.log("");
console.log("--- flags ---");
console.log("playwright-changed: " + playwrightChanged);

if (viteEntry) {
  const root = process.cwd();
  const nested = path.join(root, "node_modules/elm-pages/node_modules/vite/package.json");
  const hoisted = path.join(root, "node_modules/vite/package.json");
  const bundledPkg = fs.existsSync(nested) ? nested : hoisted;
  const bundledVersion: string = fs.existsSync(bundledPkg) ? JSON.parse(fs.readFileSync(bundledPkg, "utf8")).version : "unknown";
  console.log("");
  console.log("--- vite ---");
  console.log("current: " + viteEntry.current);
  console.log("latest: " + viteEntry.latest);
  console.log("bundled-major: " + parseInt(bundledVersion));
}
