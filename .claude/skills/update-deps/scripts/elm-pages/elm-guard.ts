// Extract dillonkearns/* package versions from app/elm.json
// and print elm-json install commands to restore them.
// Run from the project root.
const elmJson = JSON.parse(Deno.readTextFileSync("app/elm.json"));
const deps: Record<string, Record<string, string>> = elmJson.dependencies || {};
const direct: Record<string, string> = deps.direct || {};
const indirect: Record<string, string> = deps.indirect || {};

const directPkgs = Object.entries(direct)
  .filter(([name]) => name.startsWith("dillonkearns/"))
  .map(([name, version]) => ({ name, version }));

const indirectPkgs = Object.entries(indirect)
  .filter(([name]) => name.startsWith("dillonkearns/"))
  .map(([name, version]) => ({ name, version }));

console.log("--- dillonkearns packages ---");
directPkgs.forEach((p) => console.log(`${p.name}: ${p.version} (direct)`));
indirectPkgs.forEach((p) => console.log(`${p.name}: ${p.version} (indirect)`));

console.log("");
console.log(
  "--- restore commands (direct only; indirect restored transitively) ---",
);
directPkgs.forEach((p) =>
  console.log(`elm-json install --yes '${p.name}@${p.version}' -- app/elm.json`)
);
