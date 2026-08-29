import { createRoot, type Root } from "react-dom/client";
import {
  Card,
  CardContent,
  CardFooter,
  CardHeader,
  CardTitle,
} from "./ui/card";
import { sharedSheets } from "./shared-sheets";

/**
 * Design A1: React renders every part of the Card into the shadow root and
 * Elm fills named slots with content alone. Whether a footer exists is a
 * property, so the `data-slot="card-footer"` Card looks for is a node React
 * made, in the same tree as the Card itself.
 */
export class CardNamedSlots extends HTMLElement {
  private root: Root | null = null;
  private mount: HTMLElement | null = null;
  private leaving = false;
  private _footer = false;

  set footer(v: boolean) {
    this._footer = Boolean(v);
    this.render();
  }

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
      <Card data-probe="a1">
        <slot name="media" />
        <CardHeader>
          <CardTitle>
            <slot name="title" />
          </CardTitle>
        </CardHeader>
        <CardContent>
          <slot name="content" />
        </CardContent>
        {this._footer ? (
          <CardFooter>
            <slot name="footer" />
          </CardFooter>
        ) : null}
      </Card>
    );
  }
}

customElements.define("card-named-slots", CardNamedSlots);
