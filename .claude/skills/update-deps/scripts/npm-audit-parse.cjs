// Classify npm audit --json output into a structured vulnerability report.
// Pipe from: npm audit --json 2>/dev/null | node <this-script>
// Run from the project root.
const fs = require("fs");

const input = fs.readFileSync("/dev/stdin", "utf8").trim();
if (!input) {
  console.log("--- vulnerabilities ---");
  console.log("none");
  console.log("");
  console.log("--- summary ---");
  console.log("total: 0");
  process.exit(0);
}

const data = JSON.parse(input);
const vulns = data.vulnerabilities || {};
const lines = [];
let total = 0;
let fixable = 0;
let fixableBreaking = 0;

for (const [name, info] of Object.entries(vulns)) {
  total++;

  // Build description from via entries
  const titles = (info.via || [])
    .filter(v => typeof v === "object" && v.title)
    .map(v => v.title);
  const viaNames = (info.via || [])
    .filter(v => typeof v === "string");
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
    const fix = info.fixAvailable;
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
