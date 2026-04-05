// Report all Elm package versions across the three elm.json files.
// Run from the project root.
import fs from "node:fs";

const files = ["app/elm.json", "package/elm.json", "review/elm.json"];

for (const f of files) {
  const elmJson = JSON.parse(fs.readFileSync(f, "utf8"));
  const type: string = elmJson.type || "unknown";
  console.log("--- " + f + " (" + type + ") ---");

  if (type === "application") {
    const deps: Record<string, Record<string, string>> = elmJson.dependencies || {};
    const testDeps: Record<string, Record<string, string>> = elmJson["test-dependencies"] || {};

    console.log("direct:");
    for (const [name, version] of Object.entries(deps.direct || {})) {
      console.log("  " + name + ": " + version);
    }
    console.log("indirect:");
    for (const [name, version] of Object.entries(deps.indirect || {})) {
      console.log("  " + name + ": " + version);
    }
    if (Object.keys(testDeps.direct || {}).length || Object.keys(testDeps.indirect || {}).length) {
      console.log("test-direct:");
      for (const [name, version] of Object.entries(testDeps.direct || {})) {
        console.log("  " + name + ": " + version);
      }
      console.log("test-indirect:");
      for (const [name, version] of Object.entries(testDeps.indirect || {})) {
        console.log("  " + name + ": " + version);
      }
    }
  } else if (type === "package") {
    const deps: Record<string, string> = elmJson.dependencies || {};
    const testDeps: Record<string, string> = elmJson["test-dependencies"] || {};
    console.log("dependencies:");
    for (const [name, constraint] of Object.entries(deps)) {
      console.log("  " + name + ": " + constraint);
    }
    if (Object.keys(testDeps).length) {
      console.log("test-dependencies:");
      for (const [name, constraint] of Object.entries(testDeps)) {
        console.log("  " + name + ": " + constraint);
      }
    }
  }

  console.log("");
}
