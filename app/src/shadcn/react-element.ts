import { createRoot, type Root } from "react-dom/client";
import type { ReactNode } from "react";

/**
 * The lifecycle every element that mounts React shares. A subclass declares
 * its properties and a `draw`, and calls `update()` from each setter.
 *
 * `UI.Shadcn.Card` is not one of these: Card has no behaviour to borrow and its
 * classes read the tree its content sits in, so `card-elements.ts` mounts
 * nothing at all.
 */
export abstract class ReactElement extends HTMLElement {
  private root: Root | null = null;
  private leaving = false;
  private queued = false;

  protected abstract draw(): ReactNode;

  /** Elm writes one property per call, so a single update arrives as several
   * writes in a row. Coalescing them leaves React one render to do. */
  protected update() {
    if (!this.root || this.queued) return;
    this.queued = true;
    queueMicrotask(() => {
      this.queued = false;
      this.root?.render(this.draw());
    });
  }

  connectedCallback() {
    // A keyed reorder removes and re-inserts within one task, so a teardown
    // queued by that removal has to be cancelled when the node comes back.
    this.leaving = false;
    if (!this.root) this.root = createRoot(this);
    this.update();
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
}
