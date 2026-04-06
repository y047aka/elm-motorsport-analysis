// Unified elm-pages audit: version check, dillonkearns packages, and compatibilityKey.
// Pipe from: npm view elm-pages dist-tags.latest 2>/dev/null | deno run --allow-read --allow-env=HOME <this-script>
// Run from the project root.

import { type Option, isSome, fromNullable } from "./_option.ts";

function existsSync(path: string): boolean {
  try {
    Deno.statSync(path);
    return true;
  } catch {
    return false;
  }
}

// --- stdin: latest version from npm view ---
const latestRaw = (await new Response(Deno.stdin.readable).text()).trim();
const latest: Option<string> = fromNullable(latestRaw || null);

// --- 1. Current elm-pages version from app/package.json ---
const appPkg = JSON.parse(Deno.readTextFileSync("app/package.json"));
const current: string =
  appPkg.dependencies?.["elm-pages"] ??
  appPkg.devDependencies?.["elm-pages"] ??
  "unknown";

console.log("--- elm-pages version ---");
console.log(`current: ${current}`);
if (isSome(latest)) {
  console.log(`latest:  ${latest.value}`);
  console.log(`status:  ${current === latest.value ? "up to date" : "update available"}`);
} else {
  console.log("latest:  unknown (npm view failed)");
}

// --- 2. dillonkearns/* packages from app/elm.json ---
const elmJson = JSON.parse(Deno.readTextFileSync("app/elm.json"));
const deps: Record<string, Record<string, string>> = elmJson.dependencies ?? {};
const direct: Record<string, string> = deps.direct ?? {};
const indirect: Record<string, string> = deps.indirect ?? {};

const directPkgs = Object.entries(direct)
  .filter(([name]) => name.startsWith("dillonkearns/"));
const indirectPkgs = Object.entries(indirect)
  .filter(([name]) => name.startsWith("dillonkearns/"));

console.log("");
console.log("--- dillonkearns packages (app/elm.json) ---");
directPkgs.forEach(([name, version]) => console.log(`${name}: ${version} (direct)`));
indirectPkgs.forEach(([name, version]) => console.log(`${name}: ${version} (indirect)`));

console.log("");
console.log("--- restore commands (for /update-deps elm) ---");
directPkgs.forEach(([name, version]) =>
  console.log(`elm-json install --yes '${name}@${version}' -- app/elm.json`)
);

// --- 3. compatibilityKey matching ---
const root = Deno.cwd();
const npmKeyFile = `${root}/node_modules/elm-pages/src/Pages/Internal/Platform/CompatibilityKey.elm`;

console.log("");
console.log("--- compatibilityKey ---");

if (!existsSync(npmKeyFile)) {
  console.log("npmKey: unknown (file not found — run npm install first)");
  Deno.exit(0);
}

const npmSource = Deno.readTextFileSync(npmKeyFile);
const npmMatch = npmSource.match(/currentCompatibilityKey\s*=\s*(\d+)/);
if (!npmMatch) {
  console.log("npmKey: unknown (could not parse)");
  Deno.exit(0);
}

const npmKey = parseInt(npmMatch[1]);
console.log(`npmKey: ${npmKey}`);

const home = Deno.env.get("HOME");
if (!home) {
  console.log("matchingElmVersion: unknown (HOME not set)");
  Deno.exit(0);
}

const cacheDir = `${home}/.elm/0.19.1/packages/dillonkearns/elm-pages`;
if (!existsSync(cacheDir)) {
  console.log("matchingElmVersion: no-match");
  console.log(
    "Install latest to populate cache: elm-json install --yes 'dillonkearns/elm-pages@latest' -- app/elm.json",
  );
  Deno.exit(0);
}

const versions = [...Deno.readDirSync(cacheDir)].map((e) => e.name);

const matches = versions.filter((ver) => {
  const keyFile = `${cacheDir}/${ver}/src/Pages/Internal/Platform/CompatibilityKey.elm`;
  if (!existsSync(keyFile)) return false;
  const source = Deno.readTextFileSync(keyFile);
  const m = source.match(/currentCompatibilityKey\s*=\s*(\d+)/);
  return m != null && parseInt(m[1]) === npmKey;
});

function compareSemver(a: string, b: string): number {
  const pa = a.split(".").map(Number);
  const pb = b.split(".").map(Number);
  const len = Math.max(pa.length, pb.length);
  return Array.from({ length: len })
    .map((_, i) => (pa[i] || 0) - (pb[i] || 0))
    .find((d) => d !== 0) ?? 0;
}

const matchResult: Option<string> = fromNullable(matches.toSorted(compareSemver).at(-1));

if (isSome(matchResult)) {
  console.log(`matchingElmVersion: ${matchResult.value}`);
} else {
  console.log("matchingElmVersion: no-match");
  console.log(
    "Install latest to populate cache: elm-json install --yes 'dillonkearns/elm-pages@latest' -- app/elm.json",
  );
}
