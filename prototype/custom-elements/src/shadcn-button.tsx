import { createRoot, type Root } from "react-dom/client";
import { Button } from "./ui/button";
import { sharedSheets } from "./shared-sheets";

/**
 * Wraps shadcn's Button, whose content is whatever Elm put inside the element.
 *
 * Unlike the Select, this one needs a shadow root. React renders the button
 * into it and places a `<slot>` where the label goes; Elm's children stay in
 * the light DOM and the browser projects them in. Neither side ever writes to
 * the other's nodes, so Elm remains free to diff its children.
 *
 * Slotted content is styled by the page's stylesheet because it never leaves
 * the light DOM. The button React renders does leave it, so the page's rules
 * are adopted into the shadow root.
 */

export class ShadcnButton extends HTMLElement {
  private root: Root | null = null;
  private mount: HTMLElement | null = null;
  private _variant = "default";
  private _size = "default";
  private leaving = false;

  static observedAttributes = ["variant", "size"];

  attributeChangedCallback(name: string, _old: string, value: string) {
    if (name === "variant") this._variant = value || "default";
    if (name === "size") this._size = value || "default";
    this.render();
  }

  connectedCallback() {
    window.__btnStats.connects += 1;
    this.leaving = false;
    if (!this.root) {
      this.addEventListener("click", () => {
        window.__btnStats.hostClicks += 1;
      });
      const shadow = this.attachShadow({ mode: "open" });
      shadow.adoptedStyleSheets = sharedSheets();
      this.mount = document.createElement("span");
      shadow.appendChild(this.mount);
      this.root = createRoot(this.mount);
      window.__btnStats.rootsCreated += 1;
    }
    this.render();
  }

  disconnectedCallback() {
    window.__btnStats.disconnects += 1;
    this.leaving = true;
    queueMicrotask(() => {
      if (!this.leaving || this.isConnected) return;
      const root = this.root;
      this.root = null;
      if (root) {
        window.__btnStats.rootsDestroyed += 1;
        root.unmount();
      }
    });
  }

  private render() {
    if (!this.root) return;
    window.__btnStats.renders += 1;
    this.root.render(
      <Button
        variant={this._variant as never}
        size={this._size as never}
        onClick={() => {
          window.__btnStats.reactClicks += 1;
          this.dispatchEvent(new CustomEvent("button-press", { detail: null }));
        }}
      >
        <slot />
      </Button>
    );
  }
}

declare global {
  interface Window {
    __btnStats: {
      connects: number;
      disconnects: number;
      rootsCreated: number;
      rootsDestroyed: number;
      renders: number;
      reactClicks: number;
      hostClicks: number;
    };
  }
}

window.__btnStats = {
  connects: 0,
  disconnects: 0,
  rootsCreated: 0,
  rootsDestroyed: 0,
  renders: 0,
  reactClicks: 0,
  hostClicks: 0,
};

setInterval(() => {
  const el = document.getElementById("btn-stats");
  if (el) {
    const s = window.__btnStats;
    el.textContent =
      `button: connect ${s.connects} | disconnect ${s.disconnects} | ` +
      `roots +${s.rootsCreated}/-${s.rootsDestroyed} | react renders ${s.renders} | ` +
      `react onClick ${s.reactClicks} | native click on host ${s.hostClicks}`;
  }
}, 100);

customElements.define("shadcn-button", ShadcnButton);
