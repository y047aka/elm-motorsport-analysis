// Audit Rust crates for major version updates.
// Parses Cargo.toml files, runs cargo search for each crate,
// and classifies results by major version bump.
// Run from the project root.

const files = [
  "cli/Cargo.toml",
  "cli/cli/Cargo.toml",
  "cli/motorsport/Cargo.toml",
];

// Parse direct dependencies (same logic as rust-deps-parse.ts)
const seen = new Set<string>();
const deps: { name: string; constraint: string }[] = [];
for (const f of files) {
  const content = Deno.readTextFileSync(f);
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
function majorComponent(version: string): { index: number; value: number } {
  const parts = version.split(".").map(Number);
  for (const p of parts) {
    if (p !== 0) return { index: parts.indexOf(p), value: p };
  }
  return { index: 0, value: 0 };
}

function isMajorBump(current: string, latest: string): boolean {
  const c = majorComponent(current);
  const l = majorComponent(latest);
  if (c.index !== l.index) return true;
  return l.value > c.value;
}

// Strip leading constraint operators to get base version
function baseVersion(constraint: string): string {
  return constraint.replace(/^[~^>=<]*/, "");
}

const majorUpdates: string[] = [];
const upToDate: string[] = [];

for (const dep of deps) {
  let latest = "unknown";
  try {
    const cmd = new Deno.Command("cargo", {
      args: ["search", dep.name, "--limit", "1"],
      stdout: "piped",
      stderr: "null",
    });
    const { stdout } = cmd.outputSync();
    const out = new TextDecoder().decode(stdout);
    const m = out.match(new RegExp(`^${dep.name.replace(/-/g, "[-_]")}\\s.*"([^"]+)"`));
    if (m) latest = m[1];
  } catch (_) {
    // network error — report as unknown
  }

  const current = baseVersion(dep.constraint);

  if (latest !== "unknown" && isMajorBump(current, latest)) {
    majorUpdates.push(`${dep.name}: ${current} -> ${latest}`);
  } else {
    upToDate.push(`${dep.name}: ${current} (latest ${latest})`);
  }
}

console.log("--- major updates ---");
console.log(majorUpdates.length ? majorUpdates.join("\n") : "none");
console.log("");
console.log("--- up to date ---");
console.log(upToDate.length ? upToDate.join("\n") : "none");
