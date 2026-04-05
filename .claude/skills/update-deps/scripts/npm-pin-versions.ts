// Pin all workspace package.json dependency versions to the exact versions
// resolved in package-lock.json.
// Run from the project root.

const lock = JSON.parse(Deno.readTextFileSync("package-lock.json"));

function resolved(name: string, wsPrefix: string): string | null {
  if (wsPrefix) {
    const k = wsPrefix + "/node_modules/" + name;
    if (lock.packages[k]) return lock.packages[k].version;
  }
  const k = "node_modules/" + name;
  return lock.packages[k] ? lock.packages[k].version : null;
}

const workspaces: Record<string, string> = {
  "package.json": "",
  "app/package.json": "app",
  "package/package.json": "package",
  "review/package.json": "review",
};

for (const [f, ws] of Object.entries(workspaces)) {
  const pkg = JSON.parse(Deno.readTextFileSync(f));
  for (const key of ["dependencies", "devDependencies"]) {
    if (!pkg[key]) continue;
    for (const name of Object.keys(pkg[key])) {
      const v = resolved(name, ws);
      pkg[key][name] = v || pkg[key][name].replace(/^[\^~]/, "");
    }
  }
  Deno.writeTextFileSync(f, JSON.stringify(pkg, null, 2) + "\n");
}
