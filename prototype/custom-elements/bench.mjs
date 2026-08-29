// Times mounting 62 badges as custom elements against 62 plain Elm nodes.
//
// Run under Playwright rather than in the app's browser pane: that pane
// throttles animation frames, and Elm applies its patch on one, so a
// measurement taken there reports the wait for a frame rather than the work.
//
// playwright comes from the flake, not from node_modules, and ESM ignores
// NODE_PATH, so link it in first -- the same trick the repo's VRT app uses:
//
//   ln -sfn "$(dirname "$(readlink -f "$(command -v playwright)")")/../lib/node_modules/playwright" \
//     prototype/custom-elements/node_modules/playwright
//   nix develop --command bash -c 'cd prototype/custom-elements && pnpm vite --port 1236' &
//   nix develop --command bash -c 'cd prototype/custom-elements && BENCH_URL=http://localhost:1236/ node bench.mjs'

import { chromium } from "playwright";

const URL = process.env.BENCH_URL ?? "http://localhost:1235/";
const RUNS = 7;

const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto(URL, { waitUntil: "networkidle" });

// The interval that paints the counter strips mutates the DOM constantly and
// would show up in any observer; stop them before measuring.
await page.evaluate(() => {
  for (let i = 1; i < 10000; i++) clearInterval(i);
});

async function mount(mode) {
  return page.evaluate(async (mode) => {
    const list = document.getElementById("bench-list");
    const button = document.querySelector(`[data-bench="${mode}"]`);
    const target = mode === "off" ? 0 : 62;

    const t0 = performance.now();
    button.click();

    await new Promise((resolve) => {
      const check = () => {
        const n = list.querySelectorAll("[data-bench-probe]").length;
        if (n === target) {
          // Force layout so the number covers reaching the screen, not just
          // reaching the DOM.
          void list.offsetHeight;
          resolve();
        } else {
          requestAnimationFrame(check);
        }
      };
      requestAnimationFrame(check);
    });

    return performance.now() - t0;
  }, mode);
}

const results = { "plain elm": [], "custom elements": [] };

for (let run = 0; run < RUNS; run++) {
  for (const mode of ["plain elm", "custom elements"]) {
    await mount("off");
    await page.waitForTimeout(120);
    results[mode].push(await mount(mode));
    await page.waitForTimeout(120);
  }
}

const median = (xs) => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)];

console.log(`62 badges, ${RUNS} runs each (median, then all)\n`);
for (const [mode, xs] of Object.entries(results)) {
  console.log(
    `  ${mode.padEnd(16)} ${median(xs).toFixed(1)}ms   ` +
      `[${xs.map((x) => x.toFixed(0)).join(", ")}]`
  );
}

const ratio = median(results["custom elements"]) / median(results["plain elm"]);
console.log(`\n  custom elements / plain elm: ${ratio.toFixed(1)}x`);

const stats = await page.evaluate(() => window.__probeStats);
console.log(`  react roots created: ${stats.rootsCreated}`);

await browser.close();
