import { createRoot, type Root } from "react-dom/client";
import type { ReactNode } from "react";

/**
 * Whether a property Elm just wrote differs from the one held.
 *
 * Elm compares a property against the last one by reference, and re-encoding a
 * list or a record hands over a new object every view, so an unchanged value
 * still arrives as a write. Primitives are told apart by `===`; everything
 * else has to be compared by what it holds, or a view that runs every frame
 * renders React every frame.
 */
export function changed(held: unknown, next: unknown): boolean {
  if (held === next) return false;
  if (typeof held !== "object" || typeof next !== "object") return true;
  return JSON.stringify(held) !== JSON.stringify(next);
}

/**
 * The lifecycle every element that mounts React shares. A subclass declares
 * its properties and a `draw`, and calls `update()` from each setter.
 *
 * The root is the element itself, so React renders into the light DOM and the
 * page's Tailwind reaches what it draws.
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
