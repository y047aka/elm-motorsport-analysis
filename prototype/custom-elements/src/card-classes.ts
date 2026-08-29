import { cardClasses } from "./ui/card";

/**
 * Design B: no React and no shadow root. Each element puts the vendored class
 * string and `data-slot` on itself, and Elm renders the structure and its own
 * content as ordinary children. Every part and everything Elm puts inside
 * ends up in one tree, which is the tree Card's own selectors are written
 * against.
 *
 * A custom element is `display: inline` until something says otherwise, where
 * the divs upstream renders are blocks. `style.css` puts the fallback in
 * `@layer base` so the display utilities in these class strings still win.
 */
function definePart(tag: string, slot: string, className: string) {
  customElements.define(
    tag,
    class extends HTMLElement {
      connectedCallback() {
        this.setAttribute("data-slot", slot);
        this.className = className;
        if (slot === "card" && !this.hasAttribute("data-size")) {
          this.setAttribute("data-size", "default");
        }
      }
    }
  );
}

definePart("card-plain", "card", cardClasses.card);
definePart("card-plain-header", "card-header", cardClasses.header);
definePart("card-plain-title", "card-title", cardClasses.title);
definePart("card-plain-description", "card-description", cardClasses.description);
definePart("card-plain-content", "card-content", cardClasses.content);
definePart("card-plain-footer", "card-footer", cardClasses.footer);
