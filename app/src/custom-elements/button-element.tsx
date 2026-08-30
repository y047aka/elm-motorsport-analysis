import type { ComponentProps } from "react";
import { Button } from "./shadcn/button";
import { ReactElement } from "./react-element";

type Variant = ComponentProps<typeof Button>["variant"];
type Size = ComponentProps<typeof Button>["size"];
type Shape = ComponentProps<typeof Button>["shape"];

/**
 * Wraps shadcn's button so Elm can drive it. Takes its label as a property
 * rather than children, since a caller passing element children would hit
 * the rule that React's synthetic events never reach a custom element's
 * slotted children — every caller here only ever wants a text label anyway.
 *
 * A press dispatches `button-press`; Elm decides whether that means anything.
 */
export class ShadcnButton extends ReactElement {
  private _label = "";
  private _variant: Variant = "default";
  private _size: Size = "default";
  private _shape: Shape = "default";
  private _disabled = false;

  set label(v: string) {
    this._label = v;
    this.update();
  }

  set variant(v: string) {
    this._variant = (v || "default") as Variant;
    this.update();
  }

  set size(v: string) {
    this._size = (v || "default") as Size;
    this.update();
  }

  set shape(v: string) {
    this._shape = (v || "default") as Shape;
    this.update();
  }

  set disabled(v: boolean) {
    this._disabled = v;
    this.update();
  }

  protected draw() {
    return (
      <Button
        variant={this._variant}
        size={this._size}
        shape={this._shape}
        disabled={this._disabled}
        onClick={() => this.dispatchEvent(new CustomEvent("button-press"))}
      >
        {this._label}
      </Button>
    );
  }
}

customElements.define("shadcn-button", ShadcnButton);
