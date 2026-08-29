import { createRoot, type Root } from "react-dom/client";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "./ui/select";

export type Option = { value: string; label: string };

/**
 * Wraps shadcn's Select so Elm can drive it.
 *
 * React renders into the element's light DOM rather than a shadow root, so the
 * page's Tailwind stylesheet reaches the trigger. Radix portals the popup to
 * document.body on its own, which keeps it clear of any clipping ancestor.
 *
 * The element holds no selection of its own: `value` comes in as a property and
 * a pick leaves as a `value-change` event, so Elm stays the single source of
 * truth the way TEA expects.
 */
export class ShadcnSelect extends HTMLElement {
  private root: Root | null = null;
  private _options: Option[] = [];
  private _value: string | null = null;
  private _placeholder = "Select…";

  // Elm assigns properties before the element upgrades, so each setter records
  // the value and re-renders only once connectedCallback has made a root.
  set options(v: Option[]) {
    this._options = v ?? [];
    window.__ceStats.optionsSets += 1;
    this.render();
  }
  get options() {
    return this._options;
  }

  set value(v: string | null) {
    this._value = v;
    this.render();
  }
  get value() {
    return this._value;
  }

  set placeholder(v: string) {
    this._placeholder = v;
    this.render();
  }

  connectedCallback() {
    if (!this.root) this.root = createRoot(this);
    this.render();
  }

  disconnectedCallback() {
    const root = this.root;
    this.root = null;
    // React forbids unmounting while it is already rendering.
    if (root) queueMicrotask(() => root.unmount());
  }

  private render() {
    if (!this.root) return;

    this.root.render(
      <Select
        // Never undefined: React reads that as "uncontrolled" and Radix then
        // keeps its own selection, so clearing from Elm would leave the
        // trigger showing a value Elm no longer holds.
        value={this._value ?? ""}
        onValueChange={(next) => {
          window.__ceStats.eventsOut += 1;
          this.dispatchEvent(
            new CustomEvent("value-change", { detail: next, bubbles: false })
          );
        }}
      >
        <SelectTrigger className="w-56">
          <SelectValue placeholder={this._placeholder} />
        </SelectTrigger>
        <SelectContent>
          {this._options.map((o) => (
            <SelectItem key={o.value} value={o.value}>
              {o.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    );
    window.__ceStats.renders += 1;
  }
}

declare global {
  interface Window {
    __ceStats: { renders: number; eventsOut: number; optionsSets: number };
  }
}

window.__ceStats = { renders: 0, eventsOut: 0, optionsSets: 0 };

// Written into the page rather than only onto window: the counters have to be
// readable from a screenshot, since the element is driven through real clicks.
export function paintStats() {
  const el = document.getElementById("ce-stats");
  if (el) {
    const s = window.__ceStats;
    el.textContent = `react renders ${s.renders} | options set ${s.optionsSets} | events out ${s.eventsOut}`;
  }
}
setInterval(paintStats, 100);

customElements.define("shadcn-select", ShadcnSelect);
