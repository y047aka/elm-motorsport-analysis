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
  constructor() {
    super();
    this.addEventListener("pointerdown", (e) => {
      if (e.button === 0) this.setPointerCapture(e.pointerId);
    });
  }

  connectedCallback() {
    // Not in the constructor, which may not add an attribute: an element whose
    // constructor does is handed back as an `HTMLUnknownElement`, silently.
    //
    // A finger on the grip would otherwise scroll the page instead.
    this.style.touchAction = "none";
  }
}

customElements.define("drag-handle", DragHandle);
