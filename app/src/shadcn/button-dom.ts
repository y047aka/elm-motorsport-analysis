import { buttonVariants } from "./ui/button";
import { cn } from "./lib/utils";

type Variants = Parameters<typeof buttonVariants>[0];

/**
 * The button shadcn's component renders, built directly. Base UI's Button
 * adds keyboard handling for elements that only act like buttons; on the
 * `<button>` it renders by default that is the browser's own behaviour, and
 * what is left is `buttonVariants` and the attributes below.
 */
export function newButton(onPress: () => void): HTMLButtonElement {
  const button = document.createElement("button");
  button.type = "button";
  button.tabIndex = 0;
  button.dataset.slot = "button";
  button.addEventListener("click", onPress);
  return button;
}

export function drawButton(
  button: HTMLButtonElement,
  props: Variants & { label: string; disabled: boolean; className?: string }
) {
  button.className = cn(
    buttonVariants({ variant: props.variant, size: props.size }),
    props.className
  );
  button.textContent = props.label;
  button.disabled = props.disabled;
  button.toggleAttribute("data-disabled", props.disabled);
}
