import { createRoot, type Root } from "react-dom/client";
import { Button } from "./ui/button";
import { ButtonGroup } from "./ui/button-group";

type Item = {
  label: string;
  disabled: boolean;
};

/**
 * Wraps shadcn's button-group so Elm can drive it as one unit, rather than as
 * separately-mounted `shadcn-button` elements: the corner-merging between
 * adjacent segments is plain CSS matching each button's own `data-slot`
 * against its siblings, which only lines up when every button in the group
 * is rendered by the same React tree.
 *
 * The group holds no selection — that is `shadcn-toggle-group`. A press
 * dispatches `button-group-press` with the pressed item's index as `detail`.
 */
export class ShadcnButtonGroup extends HTMLElement {
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
    this.root.render(
      <ButtonGroup>
        {this._items.map((item, index) => (
          <Button
            key={index}
            size="sm"
            variant="outline"
            disabled={item.disabled}
            onClick={() =>
              this.dispatchEvent(
                new CustomEvent("button-group-press", { detail: index })
              )
            }
          >
            {item.label}
          </Button>
        ))}
      </ButtonGroup>
    );
  }
}

customElements.define("shadcn-button-group", ShadcnButtonGroup);
