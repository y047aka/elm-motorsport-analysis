import type { ComponentProps } from "react";
import { createRoot, type Root } from "react-dom/client";
import { Badge } from "./ui/badge";

type Variant = ComponentProps<typeof Badge>["variant"];

/**
 * Wraps shadcn's badge so Elm can drive it. Purely presentational (no
 * events), so unlike the slider it only ever reacts to property writes.
 */
export class ShadcnBadge extends HTMLElement {
  private root: Root | null = null;
  private leaving = false;
  private _label = "";
  private _variant: Variant = "default";

  set label(v: string) {
    this._label = v;
    this.render();
  }

  set variant(v: string) {
    this._variant = (v || "default") as Variant;
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
    this.root.render(<Badge variant={this._variant}>{this._label}</Badge>);
  }
}

customElements.define("shadcn-badge", ShadcnBadge);
