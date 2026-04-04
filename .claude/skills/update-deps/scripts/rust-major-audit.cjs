// Audit Rust crates for major version updates.
// Parses Cargo.toml files, runs cargo search for each crate,
// and classifies results by major version bump.
// Run from the project root.
const fs = require("fs");
const { execSync } = require("child_process");

const files = [
  "cli/Cargo.toml",
  "cli/cli/Cargo.toml",
  "cli/motorsport/Cargo.toml",
];

// Parse direct dependencies (same logic as rust-deps-parse.cjs)
const seen = new Set();
const deps = [];
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
      deps.push({ name: m[1], constraint: m[2] || m[3] });
    }
  }
}

// Extract leftmost non-zero component for major version comparison
function majorComponent(version) {
  const parts = version.split(".").map(Number);
  for (const p of parts) {
    if (p !== 0) return { index: parts.indexOf(p), value: p };
  }
  return { index: 0, value: 0 };
}

function isMajorBump(current, latest) {
  const c = majorComponent(current);
  const l = majorComponent(latest);
  if (c.index !== l.index) return true;
  return l.value > c.value;
}

// Strip leading constraint operators to get base version
function baseVersion(constraint) {
  return constraint.replace(/^[~^>=<]*/, "");
}

const majorUpdates = [];
const upToDate = [];

for (const dep of deps) {
  let latest = "unknown";
  try {
    const out = execSync("cargo search " + JSON.stringify(dep.name) + " --limit 1 2>/dev/null", {
      encoding: "utf8",
      timeout: 15000,
    });
    const m = out.match(new RegExp("^" + dep.name.replace(/-/g, "[-_]") + '\\s.*"([^"]+)"'));
    if (m) latest = m[1];
  } catch (_) {
    // network error or timeout — report as unknown
  }

  const current = baseVersion(dep.constraint);

  if (latest !== "unknown" && isMajorBump(current, latest)) {
    majorUpdates.push(dep.name + ": " + current + " -> " + latest);
  } else {
    upToDate.push(dep.name + ": " + current + " (latest " + latest + ")");
  }
}

console.log("--- major updates ---");
console.log(majorUpdates.length ? majorUpdates.join("\n") : "none");
console.log("");
console.log("--- up to date ---");
console.log(upToDate.length ? upToDate.join("\n") : "none");
