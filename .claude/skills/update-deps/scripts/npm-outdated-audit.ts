// Classify npm outdated --json output into minor/major update sections.
// Pipe from: npm outdated --json 2>/dev/null | deno run --allow-read <this-script>
// Run from the project root.

import { type Option, some, none, isSome, getOrElse } from "./_option.ts";

function existsSync(path: string): boolean {
  try {
    Deno.statSync(path);
    return true;
  } catch {
    return false;
  }
}

interface OutdatedInfo {
  current: string;
  wanted: string;
  latest: string;
  dependent?: string;
}

function isOutdatedData(v: unknown): v is Record<string, OutdatedInfo> {
  return typeof v === "object" && v !== null;
}

const input = (await new Response(Deno.stdin.readable).text()).trim();
if (!input) {
  console.log("--- minor updates ---");
  console.log("none");
  console.log("");
  console.log("--- major updates ---");
  console.log("none");
  Deno.exit(0);
}

const raw: unknown = JSON.parse(input);
if (!isOutdatedData(raw)) {
  console.error("unexpected npm outdated format");
  Deno.exit(1);
}
const data = raw;

const { minor, major } = Object.entries(data).reduce(
  (acc, [name, info]) => {
    const { current, wanted, latest } = info;
    const dep = info.dependent ?? "";
    return {
      minor: current !== wanted
        ? [...acc.minor, `${name}: ${current} -> ${wanted} (${dep})`]
        : acc.minor,
      major: parseInt(latest) > parseInt(current)
        ? [...acc.major, `${name}: ${current} -> ${latest} (${dep})`]
        : acc.major,
    };
  },
  { minor: [] as string[], major: [] as string[] },
);

const pw = data["@playwright/test"];
const playwrightChanged = pw != null &&
  (pw.current !== pw.wanted || parseInt(pw.latest) > parseInt(pw.current));

const vite = data["vite"];
const viteEntry = vite != null
  ? { current: vite.current, latest: vite.latest }
  : null;

console.log("--- minor updates ---");
console.log(minor.length ? minor.join("\n") : "none");
console.log("");
console.log("--- major updates ---");
console.log(major.length ? major.join("\n") : "none");
console.log("");
console.log("--- flags ---");
console.log(`playwright-changed: ${playwrightChanged}`);

if (viteEntry) {
  const root = Deno.cwd();
  const nested =
    `${root}/node_modules/elm-pages/node_modules/vite/package.json`;
  const hoisted = `${root}/node_modules/vite/package.json`;
  const bundledPkg = existsSync(nested) ? nested : hoisted;
  const bundled: Option<string> = existsSync(bundledPkg)
    ? some(JSON.parse(Deno.readTextFileSync(bundledPkg)).version)
    : none;
  console.log("");
  console.log("--- vite ---");
  console.log(`current: ${viteEntry.current}`);
  console.log(`latest: ${viteEntry.latest}`);
  console.log(
    `bundled-major: ${isSome(bundled) ? parseInt(bundled.value) : "unknown"}`,
  );
}
