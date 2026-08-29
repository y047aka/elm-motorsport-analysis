import type { ComponentProps } from "react";
import { createRoot, type Root } from "react-dom/client";
import { Button } from "./ui/button";

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
export class ShadcnButton extends HTMLElement {
  private root: Root | null = null;
  private leaving = false;
  private _label = "";
  private _variant: Variant = "default";
  private _size: Size = "default";
  private _shape: Shape = "default";
  private _disabled = false;

  set label(v: string) {
    this._label = v;
    this.render();
  }

  set variant(v: string) {
    this._variant = (v || "default") as Variant;
    this.render();
  }

  set size(v: string) {
    this._size = (v || "default") as Size;
    this.render();
  }

  set shape(v: string) {
    this._shape = (v || "default") as Shape;
    this.render();
  }

  set disabled(v: boolean) {
    this._disabled = v;
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
