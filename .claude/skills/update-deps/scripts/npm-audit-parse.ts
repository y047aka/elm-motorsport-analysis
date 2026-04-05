// Classify npm audit --json output into a structured vulnerability report.
// Pipe from: npm audit --json 2>/dev/null | deno run --allow-read <this-script>
// Run from the project root.

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

interface ViaObject {
  title?: string;
}

interface FixAvailableObject {
  name: string;
  version: string;
  isSemVerMajor?: boolean;
}

interface VulnInfo {
  severity: string;
  via: (ViaObject | string)[];
  fixAvailable: boolean | FixAvailableObject;
}

const input = readStdin().trim();
if (!input) {
  console.log("--- vulnerabilities ---");
  console.log("none");
  console.log("");
  console.log("--- summary ---");
  console.log("total: 0");
  process.exit(0);
}

const data = JSON.parse(input);
const vulns: Record<string, VulnInfo> = data.vulnerabilities || {};
const lines: string[] = [];
let total = 0;
let fixable = 0;
let fixableBreaking = 0;

for (const [name, info] of Object.entries(vulns)) {
  total++;

  // Build description from via entries
  const titles = (info.via || [])
    .filter((v): v is ViaObject => typeof v === "object" && v.title != null)
    .map(v => v.title);
  const viaNames = (info.via || [])
    .filter((v): v is string => typeof v === "string");
  const desc = titles.length
    ? titles[0]
    : viaNames.length
      ? "via " + viaNames.join(", ")
      : "";

  // Fix availability
  let fixStr = "no fix available";
  if (info.fixAvailable === true) {
    fixable++;
    fixStr = "fix available";
  } else if (info.fixAvailable && typeof info.fixAvailable === "object") {
    const fix = info.fixAvailable as FixAvailableObject;
    if (fix.isSemVerMajor) {
      fixableBreaking++;
      fixStr = "fix: " + fix.name + "@" + fix.version + " (BREAKING)";
    } else {
      fixable++;
      fixStr = "fix: " + fix.name + "@" + fix.version;
    }
  }

  lines.push(name + " (" + info.severity + "): " + desc + " — " + fixStr);
}

console.log("--- vulnerabilities ---");
console.log(lines.length ? lines.join("\n") : "none");
console.log("");
console.log("--- summary ---");
console.log("total: " + total);
console.log("fixable: " + fixable);
console.log("fixable-breaking: " + fixableBreaking);
