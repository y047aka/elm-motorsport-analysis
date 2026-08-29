import { createRoot, type Root } from "react-dom/client";
import { ToggleGroup, ToggleGroupItem } from "./ui/toggle-group";

type Item = {
  label: string;
  active: boolean;
  disabled: boolean;
};

/**
 * Wraps shadcn's toggle-group so Elm can drive it. Each item's Base UI value is
 * its index in `items`, and a selection dispatches `toggle-group-press` with
 * that index as `detail`.
 */
export class ShadcnToggleGroup extends HTMLElement {
  private root: Root | null = null;
  private leaving = false;
  private _items: Item[] = [];

  set items(v: Item[]) {
    this._items = Array.isArray(v) ? v : [];
    this.render();
  }

  connectedCallback() {
    this.leaving = false;
    if (!this.root) this.root = createRoot(this);
    this.render();
  }

  disconnectedCallback() {
    this.leaving = true;
    queueMicrotask(() => {
      if (!this.leaving || this.isConnected) return;
      const root = this.root;
      this.root = null;
      root?.unmount();
    });
  }

  private render() {
    if (!this.root) return;
    const active = this._items.findIndex((item) => item.active);
    this.root.render(
      <ToggleGroup
        variant="outline"
        size="sm"
        spacing={0}
        value={active === -1 ? [] : [String(active)]}
        onValueChange={(next) => {
          // Base UI lets the pressed item be pressed again to empty the group.
          // Elm holds the selection and has no state for "none", so a press
          // that would clear it is reported as nothing at all.
          const value = next[0];
          if (value === undefined) return;
          this.dispatchEvent(
            new CustomEvent("toggle-group-press", { detail: Number(value) })
          );
        }}
      >
        {this._items.map((item, index) => (
          <ToggleGroupItem
            key={index}
            value={String(index)}
            disabled={item.disabled}
          >
            {item.label}
          </ToggleGroupItem>
        ))}
      </ToggleGroup>
    );
  }
}

customElements.define("shadcn-toggle-group", ShadcnToggleGroup);
