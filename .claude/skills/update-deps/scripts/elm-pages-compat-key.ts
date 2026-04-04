// Match elm-pages npm compatibilityKey with the correct Elm package version.
// Run from the project root.
import fs from "fs";
import path from "path";
import os from "os";

const npmKeyFile = path.join(process.cwd(), "node_modules/elm-pages/src/Pages/Internal/Platform/CompatibilityKey.elm");
if (!fs.existsSync(npmKeyFile)) {
  console.log("error: " + npmKeyFile + " not found");
  console.log("Run npm install first.");
  process.exit(1);
}

const npmSource = fs.readFileSync(npmKeyFile, "utf8");
const npmMatch = npmSource.match(/currentCompatibilityKey\s*=\s*(\d+)/);
if (!npmMatch) {
  console.log("error: could not parse compatibilityKey from npm source");
  process.exit(1);
}

const npmKey = parseInt(npmMatch[1]);
console.log("npmKey: " + npmKey);

const cacheDir = path.join(os.homedir(), ".elm/0.19.1/packages/dillonkearns/elm-pages");
if (!fs.existsSync(cacheDir)) {
  console.log("matchingElmVersion: no-match");
  console.log("Install latest to populate cache: elm-json install --yes 'dillonkearns/elm-pages@latest' -- app/elm.json");
  process.exit(0);
}

const versions = fs.readdirSync(cacheDir);
const matches: string[] = [];

for (const ver of versions) {
  const keyFile = path.join(cacheDir, ver, "src/Pages/Internal/Platform/CompatibilityKey.elm");
  if (!fs.existsSync(keyFile)) continue;
  const source = fs.readFileSync(keyFile, "utf8");
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
  console.log("matchingElmVersion: " + matchingVersion);
} else {
  console.log("matchingElmVersion: no-match");
  console.log("Install latest to populate cache: elm-json install --yes 'dillonkearns/elm-pages@latest' -- app/elm.json");
}
