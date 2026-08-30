import { Button } from "./ui/button";
import { ButtonGroup } from "./ui/button-group";
import { ReactElement } from "./react-element";

type Item = {
  label: string;
  disabled: boolean;
};

/**
 * Wraps shadcn's button-group so Elm can drive a whole row as one element. A
 * press dispatches `button-group-press` with the pressed item's index as
 * `detail`.
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
