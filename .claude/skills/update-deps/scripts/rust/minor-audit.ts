// Classify cargo update --dry-run output into minor/patch update sections.
// Pipe from: cargo update --dry-run --manifest-path cli/Cargo.toml 2>&1 | deno run --allow-read <this-script>
// Run from the project root.

const input = (await new Response(Deno.stdin.readable).text()).trim();
if (!input) {
  console.log("--- minor updates ---");
  console.log("none");
  console.log("");
  console.log("--- patch updates ---");
  console.log("none");
  console.log("");
  console.log("--- summary ---");
  console.log("minor: 0, patch: 0");
  Deno.exit(0);
}

interface Update {
  name: string;
  from: string;
  to: string;
}

// Parse "    Updating <crate> v<old> -> v<new>" and "    Locking <crate> v<old> -> v<new>" lines
const updates: Update[] = input
  .split("\n")
  .reduce<Update[]>((acc, line) => {
    const m = line.match(/^\s+(?:Updating|Locking)\s+(\S+)\s+v(\S+)\s+->\s+v(\S+)/);
    return m ? [...acc, { name: m[1], from: m[2], to: m[3] }] : acc;
  }, []);

if (updates.length === 0) {
  console.log("--- minor updates ---");
  console.log("none");
  console.log("");
  console.log("--- patch updates ---");
  console.log("none");
  console.log("");
  console.log("--- summary ---");
  console.log("minor: 0, patch: 0");
  Deno.exit(0);
}

// Classify: compare the component immediately after the leftmost non-zero.
// If it changed → minor; otherwise → patch.
function isMinorBump(from: string, to: string): boolean {
  const fp = from.split(".").map(Number);
  const tp = to.split(".").map(Number);
  const major = fp.findIndex((p) => p !== 0);
  if (major === -1) return tp.some((p) => p !== 0);
  const next = major + 1;
  return next < fp.length && next < tp.length && tp[next] > fp[next];
}

const { minor, patch } = updates.reduce(
  (acc, u) => {
    const line = `${u.name}: ${u.from} -> ${u.to}`;
    return isMinorBump(u.from, u.to)
      ? { ...acc, minor: [...acc.minor, line] }
      : { ...acc, patch: [...acc.patch, line] };
  },
  { minor: [] as string[], patch: [] as string[] },
);

console.log("--- minor updates ---");
console.log(minor.length ? minor.join("\n") : "none");
console.log("");
console.log("--- patch updates ---");
console.log(patch.length ? patch.join("\n") : "none");
console.log("");
console.log("--- summary ---");
console.log(`minor: ${minor.length}, patch: ${patch.length}`);
