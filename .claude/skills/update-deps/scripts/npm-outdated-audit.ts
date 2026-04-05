// Classify npm outdated --json output into minor/major update sections.
// Pipe from: npm outdated --json 2>/dev/null | deno run --allow-read <this-script>
// Run from the project root.

function existsSync(path: string): boolean {
  try {
    Deno.statSync(path);
    return true;
  } catch {
    return false;
  }
}

interface OutdatedInfo {
  current: string;
  wanted: string;
  latest: string;
  dependent?: string;
}

const input = (await new Response(Deno.stdin.readable).text()).trim();
if (!input) {
  console.log("--- minor updates ---");
  console.log("none");
  console.log("");
  console.log("--- major updates ---");
  console.log("none");
  Deno.exit(0);
}

const data: Record<string, OutdatedInfo> = JSON.parse(input);

const { minor, major, playwrightChanged, viteEntry } = Object.entries(data)
  .reduce(
    (acc, [name, info]) => {
      const { current, wanted, latest } = info;
      const dep = info.dependent || "";
      const currentMajor = parseInt(current);
      const latestMajor = parseInt(latest);

      return {
        minor: current !== wanted
          ? [...acc.minor, `${name}: ${current} -> ${wanted} (${dep})`]
          : acc.minor,
        major: latestMajor > currentMajor
          ? [...acc.major, `${name}: ${current} -> ${latest} (${dep})`]
          : acc.major,
        playwrightChanged: acc.playwrightChanged ||
          (name === "@playwright/test" &&
            (current !== wanted || latestMajor > currentMajor)),
        viteEntry: name === "vite" ? { current, latest } : acc.viteEntry,
      };
    },
    {
      minor: [] as string[],
      major: [] as string[],
      playwrightChanged: false,
      viteEntry: null as { current: string; latest: string } | null,
    },
  );

console.log("--- minor updates ---");
console.log(minor.length ? minor.join("\n") : "none");
console.log("");
console.log("--- major updates ---");
console.log(major.length ? major.join("\n") : "none");
console.log("");
console.log("--- flags ---");
console.log(`playwright-changed: ${playwrightChanged}`);

if (viteEntry) {
  const root = Deno.cwd();
  const nested =
    `${root}/node_modules/elm-pages/node_modules/vite/package.json`;
  const hoisted = `${root}/node_modules/vite/package.json`;
  const bundledPkg = existsSync(nested) ? nested : hoisted;
  const bundledVersion: string = existsSync(bundledPkg)
    ? JSON.parse(Deno.readTextFileSync(bundledPkg)).version
    : "unknown";
  console.log("");
  console.log("--- vite ---");
  console.log(`current: ${viteEntry.current}`);
  console.log(`latest: ${viteEntry.latest}`);
  console.log(`bundled-major: ${parseInt(bundledVersion)}`);
}
