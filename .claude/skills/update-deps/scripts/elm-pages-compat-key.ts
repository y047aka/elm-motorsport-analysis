// Match elm-pages npm compatibilityKey with the correct Elm package version.
// Run from the project root.

function existsSync(path: string): boolean {
  try { Deno.statSync(path); return true; } catch { return false; }
}

const npmKeyFile = `${Deno.cwd()}/node_modules/elm-pages/src/Pages/Internal/Platform/CompatibilityKey.elm`;
if (!existsSync(npmKeyFile)) {
  console.log(`error: ${npmKeyFile} not found`);
  console.log("Run npm install first.");
  Deno.exit(1);
}

const npmSource = Deno.readTextFileSync(npmKeyFile);
const npmMatch = npmSource.match(/currentCompatibilityKey\s*=\s*(\d+)/);
if (!npmMatch) {
  console.log("error: could not parse compatibilityKey from npm source");
  Deno.exit(1);
}

const npmKey = parseInt(npmMatch[1]);
console.log(`npmKey: ${npmKey}`);

const home = Deno.env.get("HOME");
if (!home) {
  console.log("error: HOME not set");
  Deno.exit(1);
}
const cacheDir = `${home}/.elm/0.19.1/packages/dillonkearns/elm-pages`;
if (!existsSync(cacheDir)) {
  console.log("matchingElmVersion: no-match");
  console.log("Install latest to populate cache: elm-json install --yes 'dillonkearns/elm-pages@latest' -- app/elm.json");
  Deno.exit(0);
}

const versions = [...Deno.readDirSync(cacheDir)].map(e => e.name);
const matches: string[] = [];

for (const ver of versions) {
  const keyFile = `${cacheDir}/${ver}/src/Pages/Internal/Platform/CompatibilityKey.elm`;
  if (!existsSync(keyFile)) continue;
  const source = Deno.readTextFileSync(keyFile);
  const m = source.match(/currentCompatibilityKey\s*=\s*(\d+)/);
  if (m && parseInt(m[1]) === npmKey) {
    matches.push(ver);
  }
}

matches.sort((a: string, b: string) => {
  const pa = a.split(".").map(Number);
  const pb = b.split(".").map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const diff = (pa[i] || 0) - (pb[i] || 0);
    if (diff !== 0) return diff;
  }
  return 0;
});
const matchingVersion = matches.length ? matches[matches.length - 1] : null;

if (matchingVersion) {
  console.log(`matchingElmVersion: ${matchingVersion}`);
} else {
  console.log("matchingElmVersion: no-match");
  console.log("Install latest to populate cache: elm-json install --yes 'dillonkearns/elm-pages@latest' -- app/elm.json");
}
