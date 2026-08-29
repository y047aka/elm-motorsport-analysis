/**
 * Times how long a batch of nodes takes to reach the DOM, so the cost of a
 * React root per instance can be compared against plain Elm nodes at the size
 * the standings list actually runs at.
 *
 * Both modes mark their rendered leaf with `data-mount-probe`, so one
 * measurement covers custom elements and plain Elm without knowing which is on
 * screen.
 *
 * A MutationObserver rather than `requestAnimationFrame`: the browser pane
 * throttles frames hard enough that a rAF-based poll reports the wait for the
 * next frame instead of the work, which read as two seconds for a list that
 * was already complete.
 *
 * The number reported is the span from the first mutation to the last, not the
 * time since the click: Elm applies its patch on an animation frame, so time
 * before the first mutation is the throttled wait rather than the work.
 */

const EXPECTED = 62;
const results: string[] = [];

function report(line: string) {
  results.push(line);
  const el = document.getElementById("bench-stats");
  if (el) el.textContent = "mount: " + results.slice(-3).join("   |   ");
}

function measure(label: string) {
  const t0 = performance.now();
  let firstMutation: number | null = null;
  let lastMutation = t0;

  const observer = new MutationObserver(() => {
    const now = performance.now();
    if (firstMutation === null) firstMutation = now;
    lastMutation = now;
    if (document.querySelectorAll("[data-bench-probe]").length >= EXPECTED) {
      // Keep watching briefly: React may still be committing more nodes.
      clearTimeout(quiet);
      quiet = setTimeout(finish, 50);
    }
  });
  observer.observe(document.body, { childList: true, subtree: true });

  let quiet = setTimeout(finish, 500);

  function finish() {
    observer.disconnect();
    const found = document.querySelectorAll("[data-bench-probe]").length;
    // Time to the first mutation is mostly the wait for Elm's next animation
    // frame, which the browser pane throttles; the work is the span between
    // the first and last mutation.
    const work = firstMutation === null ? 0 : lastMutation - firstMutation;
    report(`${label}: work ${work.toFixed(1)}ms (${found}/${EXPECTED})`);
  }

}

document.addEventListener(
  "click",
  (e) => {
    const target = (e.target as HTMLElement)?.closest("[data-bench]");
    if (!target) return;
    measure(target.getAttribute("data-bench") || "?");
  },
  true // capture: start the clock before Elm's own handler runs
);
