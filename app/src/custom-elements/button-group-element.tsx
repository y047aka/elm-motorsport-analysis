import { Button } from "./shadcn/button";
import { ButtonGroup } from "./shadcn/button-group";
import { ReactElement } from "./react-element";

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
export class ShadcnButtonGroup extends ReactElement {
  private _items: Item[] = [];

  set items(v: Item[]) {
    this._items = Array.isArray(v) ? v : [];
    this.update();
  }

  protected draw() {
    return (
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
