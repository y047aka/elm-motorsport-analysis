import { createRoot, type Root } from "react-dom/client";

/**
 * A stand-in for a styling-only component (a Badge) rendered many times inside
 * a keyed list, so the cost of putting one behind a custom element can be
 * measured: a React root each, and whatever the lifecycle does when Elm
 * reorders the list.
 */
let nextInstance = 1;

export class CeProbe extends HTMLElement {
  // Fixed when the element object is constructed, so it travels with the node.
  // If Elm moves nodes these follow the labels; if it rewrites properties in
  // place they stay put while the labels shift.
  private instance = nextInstance++;
  private root: Root | null = null;
  private _label = "";
  private leaving = false;

  set label(v: string) {
    this._label = v;
    this.render();
  }

  connectedCallback() {
    window.__probeStats.connects += 1;
    // A keyed reorder removes and re-inserts the node in one task, so a
    // pending teardown from that removal is a move, not a destruction.
    this.leaving = false;
    if (!this.root) {
      this.root = createRoot(this);
      window.__probeStats.rootsCreated += 1;
    }
    this.render();
  }

  disconnectedCallback() {
    window.__probeStats.disconnects += 1;
    this.leaving = true;
    queueMicrotask(() => {
      if (!this.leaving || this.isConnected) return;
      const root = this.root;
      this.root = null;
      if (root) {
        window.__probeStats.rootsDestroyed += 1;
        root.unmount();
      }
    });
  }

  private render() {
    if (!this.root) return;
    window.__probeStats.renders += 1;
    this.root.render(
      <span data-bench-probe="" className="inline-flex h-5 items-center rounded-4xl border border-border px-2 text-xs">
        {this._label} #{this.instance}
      </span>
    );
  }
}

declare global {
  interface Window {
    __probeStats: {
      connects: number;
      disconnects: number;
      rootsCreated: number;
      rootsDestroyed: number;
      renders: number;
    };
  }
}

window.__probeStats = {
  connects: 0,
  disconnects: 0,
  rootsCreated: 0,
  rootsDestroyed: 0,
  renders: 0,
};

setInterval(() => {
  const el = document.getElementById("probe-stats");
  if (el) {
    const s = window.__probeStats;
    el.textContent =
      `probe: connect ${s.connects} | disconnect ${s.disconnects} | ` +
      `roots +${s.rootsCreated}/-${s.rootsDestroyed} | react renders ${s.renders}`;
  }
}, 100);

customElements.define("ce-probe", CeProbe);
