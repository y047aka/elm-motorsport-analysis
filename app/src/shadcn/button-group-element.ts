import { buttonGroupVariants } from "./ui/button-group";
import { changed } from "./react-element";
import { drawButton, newButton } from "./button-dom";

type Item = {
  label: string;
  disabled: boolean;
};

/**
 * Button-group, driven from Elm as one element rather than as a row of
 * `shadcn-button`s: the corner-merging between segments is CSS matching a
 * button's `data-slot` against its siblings, so they have to share a parent.
 * A press dispatches `button-group-press` with the pressed item's index as
 * `detail`.
 */
export class ShadcnButtonGroup extends HTMLElement {
  private row = document.createElement("div");
  private _items: Item[] = [];

  set items(v: Item[]) {
    const next = Array.isArray(v) ? v : [];
    if (!changed(this._items, next)) return;
    this._items = next;
    this.draw();
  }

  connectedCallback() {
    this.draw();
    if (this.row.parentNode !== this) this.appendChild(this.row);
  }

  private draw() {
    this.row.role = "group";
    this.row.dataset.slot = "button-group";
    this.row.className = buttonGroupVariants();

    while (this.row.childElementCount > this._items.length) {
      this.row.lastElementChild?.remove();
    }
    this._items.forEach((item, index) => {
      let button = this.row.children[index] as HTMLButtonElement | undefined;
      if (!button) {
        // The index a button reports is its position, which is the position it
        // keeps: the row only ever grows or shrinks from the end.
        button = newButton(() =>
          this.dispatchEvent(
            new CustomEvent("button-group-press", { detail: index })
          )
        );
        this.row.appendChild(button);
      }
      drawButton(button, {
        label: item.label,
        variant: "outline",
        size: "sm",
        disabled: item.disabled,
      });
    });
  }
}

customElements.define("shadcn-button-group", ShadcnButtonGroup);
