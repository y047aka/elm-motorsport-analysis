/**
 * A grip Elm drags by. Elm has no way to call `setPointerCapture`, and without
 * it the pointer's moves go to whatever is under it once it leaves the grip.
 * Captured, every move and the release come back to this element, for a mouse
 * and a finger alike, so Elm listens here and nowhere else.
 *
 * Capture is released when the element leaves the document, so what it sits in
 * must not be moved while it is held.
 */
export class DragHandle extends HTMLElement {
  #held = new Set<number>();

  constructor() {
    super();
    this.addEventListener("pointerdown", (e) => {
      if (e.button !== 0) return;
      this.setPointerCapture(e.pointerId);
      this.#held.add(e.pointerId);
    });
    this.addEventListener("lostpointercapture", (e) => {
      this.#held.delete(e.pointerId);
    });
  }

  connectedCallback() {
    // Not in the constructor, which may not add an attribute: an element whose
    // constructor does is handed back as an `HTMLUnknownElement`, silently.
    //
    // A finger on the grip would otherwise scroll the page instead.
    this.style.touchAction = "none";
  }

  disconnectedCallback() {
    // The capture lost by leaving the document is reported to the document
    // rather than to this element, so nothing listening here would hear the
    // carry end. It is reported here instead, and a microtask later: this runs
    // while Elm is patching the DOM, and a message sent mid-patch is not drawn
    // until the one after it.
    const held = [...this.#held];
    this.#held.clear();
    queueMicrotask(() => {
      for (const pointerId of held) {
        this.dispatchEvent(new PointerEvent("pointercancel", { pointerId }));
      }
    });
  }
}

customElements.define("drag-handle", DragHandle);
