import { ToggleGroup, ToggleGroupItem } from "./ui/toggle-group";
import { ReactElement, changed } from "./react-element";

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
export class ShadcnToggleGroup extends ReactElement {
  private _items: Item[] = [];

  set items(v: Item[]) {
    const next = Array.isArray(v) ? v : [];
    if (!changed(this._items, next)) return;
    this._items = next;
    this.update();
  }

  protected draw() {
    const active = this._items.findIndex((item) => item.active);
    return (
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
