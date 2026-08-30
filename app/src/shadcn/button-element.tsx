import type { ComponentProps } from "react";
import { Button } from "./ui/button";
import { ReactElement } from "./react-element";

type Variant = ComponentProps<typeof Button>["variant"];
type Size = ComponentProps<typeof Button>["size"];
type Shape = "default" | "circle";

/**
 * Wraps shadcn's button so Elm can drive it. The label is a property, not
 * children: a slotted child's clicks would never reach React. A press
 * dispatches `button-press`.
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
    this._shape = v === "circle" ? "circle" : "default";
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
        // `cn` puts className last, so this wins over the `rounded-*` the
        // size variants set.
        className={this._shape === "circle" ? "rounded-full" : undefined}
        disabled={this._disabled}
        onClick={() => this.dispatchEvent(new CustomEvent("button-press"))}
      >
        {this._label}
      </Button>
    );
  }
}

customElements.define("shadcn-button", ShadcnButton);
