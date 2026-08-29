import { createRoot, type Root } from "react-dom/client";
import { Card } from "./ui/card";
import { sharedSheets } from "./shared-sheets";

/**
 * Design A2, the naive reading of "put Elm content inside shadcn's Card":
 * React renders only the outer Card into a shadow root, and everything inside
 * -- header, content, footer -- comes from Elm through a `<slot>`.
 *
 * Card decides its own padding from what it contains
 * (`has-data-[slot=card-footer]:pb-0`, `has-[>img:first-child]:pt-0`), and the
 * question this answers is whether those selectors can see across the slot.
 */
export class CardSlotted extends HTMLElement {
  private root: Root | null = null;
  private mount: HTMLElement | null = null;
  private leaving = false;

  connectedCallback() {
    this.leaving = false;
    if (!this.root) {
      const shadow = this.attachShadow({ mode: "open" });
      shadow.adoptedStyleSheets = sharedSheets();
      this.mount = document.createElement("span");
      shadow.appendChild(this.mount);
      this.root = createRoot(this.mount);
    }
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
      <Card data-probe="a2">
        <slot />
      </Card>
    );
  }
}

customElements.define("card-slotted", CardSlotted);
