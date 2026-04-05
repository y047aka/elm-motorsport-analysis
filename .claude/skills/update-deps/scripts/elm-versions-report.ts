// Report all Elm package versions across the three elm.json files.
// Run from the project root.
const files = ["app/elm.json", "package/elm.json", "review/elm.json"];

files.forEach((f) => {
  const elmJson = JSON.parse(Deno.readTextFileSync(f));
  const type: string = elmJson.type || "unknown";
  console.log(`--- ${f} (${type}) ---`);

  if (type === "application") {
    const deps: Record<string, Record<string, string>> = elmJson.dependencies ||
      {};
    const testDeps: Record<string, Record<string, string>> =
      elmJson["test-dependencies"] || {};

    console.log("direct:");
    Object.entries(deps.direct || {}).forEach(([name, version]) =>
      console.log(`  ${name}: ${version}`)
    );
    console.log("indirect:");
    Object.entries(deps.indirect || {}).forEach(([name, version]) =>
      console.log(`  ${name}: ${version}`)
    );
    if (
      Object.keys(testDeps.direct || {}).length ||
      Object.keys(testDeps.indirect || {}).length
    ) {
      console.log("test-direct:");
      Object.entries(testDeps.direct || {}).forEach(([name, version]) =>
        console.log(`  ${name}: ${version}`)
      );
      console.log("test-indirect:");
      Object.entries(testDeps.indirect || {}).forEach(([name, version]) =>
        console.log(`  ${name}: ${version}`)
      );
    }
  } else if (type === "package") {
    const deps: Record<string, string> = elmJson.dependencies || {};
    const testDeps: Record<string, string> = elmJson["test-dependencies"] || {};
    console.log("dependencies:");
    Object.entries(deps).forEach(([name, constraint]) =>
      console.log(`  ${name}: ${constraint}`)
    );
    if (Object.keys(testDeps).length) {
      console.log("test-dependencies:");
      Object.entries(testDeps).forEach(([name, constraint]) =>
        console.log(`  ${name}: ${constraint}`)
      );
    }
  }

  console.log("");
});
