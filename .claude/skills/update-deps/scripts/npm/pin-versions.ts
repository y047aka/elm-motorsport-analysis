// Pin all workspace package.json dependency versions to the exact versions
// resolved in package-lock.json.
// Run from the project root.

import { type Option, some, none, getOrElse } from "../_shared/option.ts";

const lock = JSON.parse(Deno.readTextFileSync("package-lock.json"));

function resolved(name: string, wsPrefix: string): Option<string> {
  if (wsPrefix) {
    const k = wsPrefix + "/node_modules/" + name;
    if (lock.packages[k]) return some(lock.packages[k].version);
  }
  const k = "node_modules/" + name;
  return lock.packages[k] ? some(lock.packages[k].version) : none;
}

const workspaces: Record<string, string> = {
  "package.json": "",
  "app/package.json": "app",
  "package/package.json": "package",
  "review/package.json": "review",
};

Object.entries(workspaces).forEach(([f, ws]) => {
  const pkg = JSON.parse(Deno.readTextFileSync(f));
  ["dependencies", "devDependencies"]
    .filter((key) => pkg[key])
    .forEach((key) => {
      pkg[key] = Object.fromEntries(
        Object.entries(pkg[key] as Record<string, string>).map((
          [name, ver],
        ) => [
          name,
          getOrElse(resolved(name, ws), ver.replace(/^[\^~]/, "")),
        ]),
      );
    });
  Deno.writeTextFileSync(f, JSON.stringify(pkg, null, 2) + "\n");
});
