// Extract dillonkearns/* package versions from app/elm.json
// and print elm-json install commands to restore them.
// Run from the project root.
import fs from "node:fs";

const elmJson = JSON.parse(fs.readFileSync("app/elm.json", "utf8"));
const deps: Record<string, Record<string, string>> = elmJson.dependencies || {};
const direct: Record<string, string> = deps.direct || {};
const indirect: Record<string, string> = deps.indirect || {};

const directPkgs: { name: string; version: string }[] = [];
const indirectPkgs: { name: string; version: string }[] = [];

for (const [name, version] of Object.entries(direct)) {
  if (name.startsWith("dillonkearns/")) {
    directPkgs.push({ name: name, version: version });
  }
}

for (const [name, version] of Object.entries(indirect)) {
  if (name.startsWith("dillonkearns/")) {
    indirectPkgs.push({ name: name, version: version });
  }
}

console.log("--- dillonkearns packages ---");
for (const p of directPkgs) {
  console.log(p.name + ": " + p.version + " (direct)");
}
for (const p of indirectPkgs) {
  console.log(p.name + ": " + p.version + " (indirect)");
}

console.log("");
console.log("--- restore commands (direct only; indirect restored transitively) ---");
for (const p of directPkgs) {
  console.log("elm-json install --yes '" + p.name + "@" + p.version + "' -- app/elm.json");
}
