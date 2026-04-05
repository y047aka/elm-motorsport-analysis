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
const allDeps = files.flatMap((f) =>
  Deno.readTextFileSync(f).split("\n").reduce<
    { inDeps: boolean; deps: { name: string; constraint: string }[] }
  >(
    (acc, line) => {
      if (/^\[(workspace\.)?(dev-)?dependencies\]/.test(line)) {
        return { ...acc, inDeps: true };
      }
      if (/^\[/.test(line)) return { ...acc, inDeps: false };
      if (!acc.inDeps) return acc;
      const m = line.match(
        /^([\w-]+)\s*=\s*(?:"([^"]+)"|.*version\s*=\s*"([^"]+)")/,
      );
      return m
        ? {
          ...acc,
          deps: [...acc.deps, { name: m[1], constraint: m[2] || m[3] }],
        }
        : acc;
    },
    { inDeps: false, deps: [] },
  ).deps
);
const deps = [...new Map(allDeps.map((d) => [d.name, d])).values()];

// Extract leftmost non-zero component for major version comparison
function majorComponent(version: string): { index: number; value: number } {
  const parts = version.split(".").map(Number);
  const idx = parts.findIndex((p) => p !== 0);
  return idx === -1
    ? { index: 0, value: 0 }
    : { index: idx, value: parts[idx] };
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

const classified = await Promise.all(
  deps.map(async (dep) => {
    let latest = "unknown";
    try {
      const cmd = new Deno.Command("cargo", {
        args: ["search", dep.name, "--limit", "1"],
        stdout: "piped",
        stderr: "null",
      });
      const out = new TextDecoder().decode((await cmd.output()).stdout);
      const m = out.match(
        new RegExp(`^${dep.name.replace(/-/g, "[-_]")}\\s.*"([^"]+)"`),
      );
      if (m) latest = m[1];
    } catch (_) {
      // network error — report as unknown
    }
    return { ...dep, latest, current: baseVersion(dep.constraint) };
  }),
);

const grouped = Map.groupBy(
  classified,
  ({ current, latest }) =>
    latest !== "unknown" && isMajorBump(current, latest) ? "major" : "upToDate",
);
const majorUpdates = (grouped.get("major") ?? []).map(
  ({ name, current, latest }) => `${name}: ${current} -> ${latest}`,
);
const upToDate = (grouped.get("upToDate") ?? []).map(
  ({ name, current, latest }) => `${name}: ${current} (latest ${latest})`,
);

console.log("--- major updates ---");
console.log(majorUpdates.length ? majorUpdates.join("\n") : "none");
console.log("");
console.log("--- up to date ---");
console.log(upToDate.length ? upToDate.join("\n") : "none");
