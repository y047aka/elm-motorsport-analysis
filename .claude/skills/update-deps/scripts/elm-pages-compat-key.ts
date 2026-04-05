// Match elm-pages npm compatibilityKey with the correct Elm package version.
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

const npmKeyFile =
  `${Deno.cwd()}/node_modules/elm-pages/src/Pages/Internal/Platform/CompatibilityKey.elm`;
if (!existsSync(npmKeyFile)) {
  console.error(`${npmKeyFile} not found`);
  console.error("Run npm install first.");
  Deno.exit(1);
}

const npmSource = Deno.readTextFileSync(npmKeyFile);
const npmMatch = npmSource.match(/currentCompatibilityKey\s*=\s*(\d+)/);
if (!npmMatch) {
  console.error("could not parse compatibilityKey from npm source");
  Deno.exit(1);
}

const npmKey = parseInt(npmMatch[1]);
console.log(`npmKey: ${npmKey}`);

const home = Deno.env.get("HOME");
if (!home) {
  console.error("HOME not set");
  Deno.exit(1);
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
  const keyFile =
    `${cacheDir}/${ver}/src/Pages/Internal/Platform/CompatibilityKey.elm`;
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
