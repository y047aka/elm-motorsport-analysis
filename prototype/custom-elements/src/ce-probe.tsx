import { useEffect } from "react";
import { ReactElement } from "@/shadcn/react-element";

/**
 * A stand-in for a styling-only component (a Badge) rendered many times inside
 * a keyed list, so the cost of putting one behind a custom element can be
 * measured: a React root each, and whatever the lifecycle does when Elm
 * reorders the list.
 *
 * It extends the app's own `ReactElement`, so what is measured is the
 * lifecycle the app ships rather than a second copy of it.
 */
let nextInstance = 1;

function Probe({ label, instance }: { label: string; instance: number }) {
  // A React root that is torn down and rebuilt mounts this again; one that
  // survives a move re-renders it without remounting. That difference is the
  // whole question a reorder asks.
  useEffect(() => {
    window.__probeStats.reactMounts += 1;
  }, []);

  return (
    <span data-bench-probe="" className="inline-flex h-5 items-center rounded-4xl border border-border px-2 text-xs">
      {label} #{instance}
    </span>
  );
}

export class CeProbe extends ReactElement {
  // Fixed when the element object is constructed, so it travels with the node.
  // If Elm moves nodes these follow the labels; if it rewrites properties in
  // place they stay put while the labels shift.
  private instance = nextInstance++;
  private _label = "";

  set label(v: string) {
    this._label = v;
    this.update();
  }

  connectedCallback() {
    window.__probeStats.connects += 1;
    super.connectedCallback();
  }

  disconnectedCallback() {
    window.__probeStats.disconnects += 1;
    super.disconnectedCallback();
  }

  protected draw() {
    window.__probeStats.renders += 1;
    return <Probe label={this._label} instance={this.instance} />;
  }
}

declare global {
  interface Window {
    __probeStats: {
      connects: number;
      disconnects: number;
      reactMounts: number;
      renders: number;
    };
  }
}

window.__probeStats = {
  connects: 0,
  disconnects: 0,
  reactMounts: 0,
  renders: 0,
};

setInterval(() => {
  const el = document.getElementById("probe-stats");
  if (el) {
    const s = window.__probeStats;
    el.textContent =
      `probe: connect ${s.connects} | disconnect ${s.disconnects} | ` +
      `react mounts ${s.reactMounts} | react renders ${s.renders}`;
  }
}, 100);

customElements.define("ce-probe", CeProbe);
