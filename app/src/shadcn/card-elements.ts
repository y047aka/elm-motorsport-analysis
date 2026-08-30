import { cardClasses } from "./ui/card";

/**
 * Card, driven from Elm without React. Card must not mount a root: its rules
 * read the tree its content sits in --- `has-data-[slot=card-footer]:pb-0`,
 * `has-[>img:first-child]:pt-0` --- and content projected through a `<slot>`
 * is not in that tree. Putting the vendored class string on the element
 * itself leaves Elm's structure and Card's rules in one tree.
 *
 * Nothing else may set `class` on these elements: an Elm-side class would be
 * overwritten here on connect and would overwrite this on the next patch.
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
