import { buttonVariants } from "./ui/button";
import { drawButton, newButton } from "./button-dom";

type Variants = NonNullable<Parameters<typeof buttonVariants>[0]>;

/**
 * Button, driven from Elm. The label is a property, not children: the
 * element renders the `<button>` itself, and children Elm rendered would
 * land beside it rather than inside it. A press dispatches `button-press`.
 */
export class ShadcnButton extends HTMLElement {
  private button = newButton(() =>
    this.dispatchEvent(new CustomEvent("button-press"))
  );
  private _label = "";
  private _variant: Variants["variant"] = "default";
  private _size: Variants["size"] = "default";
  private _circle = false;
  private _disabled = false;

  set label(v: string) {
    this._label = v;
    this.draw();
  }

  set variant(v: string) {
    this._variant = (v || "default") as Variants["variant"];
    this.draw();
  }

  set size(v: string) {
    this._size = (v || "default") as Variants["size"];
    this.draw();
  }

  set shape(v: string) {
    this._circle = v === "circle";
    this.draw();
  }

  set disabled(v: boolean) {
    this._disabled = v;
    this.draw();
  }

  connectedCallback() {
    this.draw();
    if (this.button.parentNode !== this) this.appendChild(this.button);
  }

  private draw() {
    drawButton(this.button, {
      label: this._label,
      variant: this._variant,
      size: this._size,
      disabled: this._disabled,
      // `cn` puts className last, so this wins over the `rounded-*` the size
      // variants set.
      className: this._circle ? "rounded-full" : undefined,
    });
  }
}

customElements.define("shadcn-button", ShadcnButton);
