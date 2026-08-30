import type { ComponentProps } from "react";
import { Badge } from "./ui/badge";
import { ReactElement } from "./react-element";

type Variant = ComponentProps<typeof Badge>["variant"];

/**
 * Wraps shadcn's badge so Elm can drive it. Purely presentational (no
 * events), so unlike the slider it only ever reacts to property writes.
 */
export class ShadcnBadge extends ReactElement {
  private _label = "";
  private _variant: Variant = "default";

  set label(v: string) {
    this._label = v;
    this.update();
  }

  set variant(v: string) {
    this._variant = (v || "default") as Variant;
    this.update();
  }

  protected draw() {
    return <Badge variant={this._variant}>{this._label}</Badge>;
  }
}

customElements.define("shadcn-badge", ShadcnBadge);
