// Classify npm outdated --json output into minor/major update sections.
// Pipe from: npm outdated --json 2>/dev/null | node <this-script>
// Run from the project root.
const fs = require("fs");
const path = require("path");

const input = fs.readFileSync("/dev/stdin", "utf8").trim();
if (!input) {
  console.log("--- minor updates ---");
  console.log("none");
  console.log("");
  console.log("--- major updates ---");
  console.log("none");
  process.exit(0);
}

const data = JSON.parse(input);
const minor = [];
const major = [];
let playwrightChanged = false;
let viteEntry = null;

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
  const bundledVersion = fs.existsSync(bundledPkg) ? require(bundledPkg).version : "unknown";
  console.log("");
  console.log("--- vite ---");
  console.log("current: " + viteEntry.current);
  console.log("latest: " + viteEntry.latest);
  console.log("bundled-major: " + parseInt(bundledVersion));
}
