import { badgeVariants } from "./ui/badge";
import { cn } from "./lib/utils";

type Variant = NonNullable<Parameters<typeof badgeVariants>[0]>["variant"];

/**
 * Badge, driven from Elm. Nothing here is React's to do: the component is a
 * `<span>` carrying `badgeVariants`, which the registry exports.
 */
export class ShadcnBadge extends HTMLElement {
  private span = document.createElement("span");
  private _label = "";
  private _variant: Variant = "default";

  set label(v: string) {
    this._label = v;
    this.draw();
  }

  set variant(v: string) {
    this._variant = (v || "default") as Variant;
    this.draw();
  }

  connectedCallback() {
    this.draw();
    if (this.span.parentNode !== this) this.appendChild(this.span);
  }

  private draw() {
    this.span.dataset.slot = "badge";
    this.span.dataset.variant = this._variant ?? "default";
    // As the component does: `cn` drops the base's `border-transparent`
    // when a variant sets a border colour.
    this.span.className = cn(badgeVariants({ variant: this._variant }));
    this.span.textContent = this._label;
  }
}

customElements.define("shadcn-badge", ShadcnBadge);
