// Audit Rust crates for major version updates.
// Parses Cargo.toml files, runs cargo search for each crate,
// and classifies results by major version bump.
// Run from the project root.

const files = [
  "cli/Cargo.toml",
  "cli/cli/Cargo.toml",
  "cli/motorsport/Cargo.toml",
];

interface CrateDep {
  name: string;
  constraint: string;
}

interface DepsParseState {
  inDeps: boolean;
  deps: CrateDep[];
}

// Parse direct dependencies (same logic as rust-deps-parse.ts)
const allDeps = files.flatMap((f) =>
  Deno.readTextFileSync(f).split("\n").reduce<DepsParseState>(
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

interface MajorComponent {
  index: number;
  value: number;
}

// Extract leftmost non-zero component for major version comparison
function majorComponent(version: string): MajorComponent {
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

type VersionLookup =
  | { status: "found"; version: string }
  | { status: "unknown" };

const decoder = new TextDecoder();

async function fetchLatestVersion(name: string): Promise<VersionLookup> {
  try {
    const cmd = new Deno.Command("cargo", {
      args: ["search", name, "--limit", "1"],
      stdout: "piped",
      stderr: "null",
    });
    const out = decoder.decode((await cmd.output()).stdout);
    const m = out.match(new RegExp(`^${name.replace(/-/g, "[-_]")}\\s.*"([^"]+)"`));
    return m ? { status: "found", version: m[1] } : { status: "unknown" };
  } catch (_) {
    // network error — report as unknown
    return { status: "unknown" };
  }
}

const classified = await Promise.all(
  deps.map(async (dep) => {
    const latest = await fetchLatestVersion(dep.name);
    return { ...dep, latest, current: baseVersion(dep.constraint) };
  }),
);

type ClassifiedDep = (typeof classified)[number];
type FoundDep = Omit<ClassifiedDep, "latest"> & {
  latest: { status: "found"; version: string };
};

const majorUpdates = classified
  .filter((d): d is FoundDep =>
    d.latest.status === "found" && isMajorBump(d.current, d.latest.version)
  )
  .map(({ name, current, latest }) => `${name}: ${current} -> ${latest.version}`);

const upToDate = classified
  .filter((d) =>
    !(d.latest.status === "found" && isMajorBump(d.current, d.latest.version))
  )
  .map(({ name, current, latest }) =>
    `${name}: ${current} (latest ${latest.status === "found" ? latest.version : "unknown"})`
  );

console.log("--- major updates ---");
console.log(majorUpdates.length ? majorUpdates.join("\n") : "none");
console.log("");
console.log("--- up to date ---");
console.log(upToDate.length ? upToDate.join("\n") : "none");
