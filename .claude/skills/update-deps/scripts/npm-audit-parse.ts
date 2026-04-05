// Classify npm audit --json output into a structured vulnerability report.
// Pipe from: npm audit --json 2>/dev/null | deno run --allow-read <this-script>
// Run from the project root.

interface ViaObject {
  title?: string;
}

interface FixAvailableObject {
  name: string;
  version: string;
  isSemVerMajor?: boolean;
}

type Severity = "info" | "low" | "moderate" | "high" | "critical";

interface VulnInfo {
  severity: Severity;
  via: (ViaObject | string)[];
  fixAvailable: boolean | FixAvailableObject;
}

function isFixAvailableObject(
  v: boolean | FixAvailableObject,
): v is FixAvailableObject {
  return typeof v === "object" && v !== null && "name" in v;
}

const input = (await new Response(Deno.stdin.readable).text()).trim();
if (!input) {
  console.log("--- vulnerabilities ---");
  console.log("none");
  console.log("");
  console.log("--- summary ---");
  console.log("total: 0");
  Deno.exit(0);
}

interface AuditData {
  vulnerabilities?: Record<string, VulnInfo>;
}

function isAuditData(v: unknown): v is AuditData {
  return typeof v === "object" && v !== null;
}

const raw: unknown = JSON.parse(input);
if (!isAuditData(raw)) {
  console.error("unexpected npm audit format");
  Deno.exit(1);
}
const data = raw;
const vulns: Record<string, VulnInfo> = data.vulnerabilities ?? {};
const total = Object.keys(vulns).length;

const { lines, fixable, fixableBreaking } = Object.entries(vulns).reduce(
  (acc, [name, info]) => {
    // Build description from via entries
    const titles = (info.via ?? [])
      .filter((v): v is ViaObject => typeof v === "object" && v.title != null)
      .map((v) => v.title);
    const viaNames = (info.via ?? [])
      .filter((v): v is string => typeof v === "string");
    const desc = titles.length
      ? titles[0]
      : viaNames.length
      ? `via ${viaNames.join(", ")}`
      : "";

    // Fix availability
    const fix = isFixAvailableObject(info.fixAvailable)
      ? info.fixAvailable
      : null;
    const [fixStr, fixKind]: [string, "fixable" | "breaking" | "none"] =
      info.fixAvailable === true
        ? ["fix available", "fixable"]
        : fix?.isSemVerMajor
        ? [`fix: ${fix.name}@${fix.version} (BREAKING)`, "breaking"]
        : fix
        ? [`fix: ${fix.name}@${fix.version}`, "fixable"]
        : ["no fix available", "none"];

    return {
      lines: [...acc.lines, `${name} (${info.severity}): ${desc} — ${fixStr}`],
      fixable: acc.fixable + (fixKind === "fixable" ? 1 : 0),
      fixableBreaking: acc.fixableBreaking + (fixKind === "breaking" ? 1 : 0),
    };
  },
  { lines: [] as string[], fixable: 0, fixableBreaking: 0 },
);

console.log("--- vulnerabilities ---");
console.log(lines.length ? lines.join("\n") : "none");
console.log("");
console.log("--- summary ---");
console.log(`total: ${total}`);
console.log(`fixable: ${fixable}`);
console.log(`fixable-breaking: ${fixableBreaking}`);
