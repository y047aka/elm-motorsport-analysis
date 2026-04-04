// Parse direct dependencies from all Cargo.toml files in the workspace.
// Outputs one line per unique crate: "crate-name version-constraint"
// Run from the project root.
const fs = require("fs");
const files = [
  "cli/Cargo.toml",
  "cli/cli/Cargo.toml",
  "cli/motorsport/Cargo.toml",
];
const seen = new Set();
for (const f of files) {
  const content = fs.readFileSync(f, "utf8");
  let inDeps = false;
  for (const line of content.split("\n")) {
    if (/^\[(workspace\.)?(dev-)?dependencies\]/.test(line)) {
      inDeps = true;
      continue;
    }
    if (/^\[/.test(line)) {
      inDeps = false;
      continue;
    }
    if (!inDeps) continue;
    const m = line.match(
      /^([\w-]+)\s*=\s*(?:"([^"]+)"|.*version\s*=\s*"([^"]+)")/
    );
    if (m && !seen.has(m[1])) {
      seen.add(m[1]);
      console.log(m[1] + " " + (m[2] || m[3]));
    }
  }
}
