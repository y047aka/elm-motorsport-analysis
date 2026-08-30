import { cardClasses } from "./ui/card";

/**
 * Card, driven from Elm without React. Every other component here mounts a
 * React root; Card must not, because its own rules read the tree its content
 * sits in --- `has-data-[slot=card-footer]:pb-0`, `has-[>img:first-child]:pt-0`,
 * `*:[img:first-child]:rounded-t-xl` --- and content projected through a
 * `<slot>` is not in the shadow root's tree. Each element puts the vendored
 * class string and `data-slot` on itself and Elm renders the structure, so
 * there is one tree and the rules resolve as upstream wrote them.
 *
 * Nothing else may set `class` on these elements: the element owns that
 * attribute outright, and an Elm-side class would be overwritten here on
 * connect and would overwrite this on the next patch. Layout belongs on a
 * wrapper the caller renders.
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

definePart("shadcn-card", "card", cardClasses.card);
definePart("shadcn-card-header", "card-header", cardClasses.header);
definePart("shadcn-card-title", "card-title", cardClasses.title);
definePart("shadcn-card-description", "card-description", cardClasses.description);
definePart("shadcn-card-action", "card-action", cardClasses.action);
definePart("shadcn-card-content", "card-content", cardClasses.content);
definePart("shadcn-card-footer", "card-footer", cardClasses.footer);
