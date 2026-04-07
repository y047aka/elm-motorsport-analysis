// Audit Rust crates for major version updates.
// Parses Cargo.toml files, runs cargo search for each crate,
// and classifies results by major version bump.
// Run from the project root.

import { type Option, type Some, some, none, isSome, getOrElse } from "../_shared/option.ts";

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

const decoder = new TextDecoder();

async function fetchLatestVersion(name: string): Promise<Option<string>> {
  try {
    const cmd = new Deno.Command("cargo", {
      args: ["search", name, "--limit", "1"],
      stdout: "piped",
      stderr: "null",
    });
    const out = decoder.decode((await cmd.output()).stdout);
    const m = out.match(new RegExp(`^${name.replace(/-/g, "[-_]")}\\s.*"([^"]+)"`));
    return m ? some(m[1]) : none;
  } catch (_) {
    // network error — report as unknown
    return none;
  }
}

const classified = await Promise.all(
  deps.map(async (dep) => {
    const latest = await fetchLatestVersion(dep.name);
    return { ...dep, latest, current: baseVersion(dep.constraint) };
  }),
);

type ClassifiedDep = (typeof classified)[number];
type FoundDep = Omit<ClassifiedDep, "latest"> & { latest: Some<string> };

function isMajorUpdate(d: ClassifiedDep): d is FoundDep {
  return isSome(d.latest) && isMajorBump(d.current, d.latest.value);
}

const [majorDeps, upToDateDeps] = classified.reduce<[FoundDep[], ClassifiedDep[]]>(
  ([maj, utd], d) => isMajorUpdate(d) ? [[...maj, d], utd] : [maj, [...utd, d]],
  [[], []],
);

const majorUpdates = majorDeps.map(({ name, current, latest }) =>
  `${name}: ${current} -> ${latest.value}`
);
const upToDate = upToDateDeps.map(({ name, current, latest }) =>
  `${name}: ${current} (latest ${getOrElse(latest, "unknown")})`
);

console.log("--- major updates ---");
console.log(majorUpdates.length ? majorUpdates.join("\n") : "none");
console.log("");
console.log("--- up to date ---");
console.log(upToDate.length ? upToDate.join("\n") : "none");
