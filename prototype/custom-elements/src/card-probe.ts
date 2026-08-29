/**
 * Paints what each of the three cards computed to. Card's own rules are
 * conditional on what it contains, so the numbers are the answer:
 *
 *   pb   16px until `has-data-[slot=card-footer]` fires, then 0px
 *   pt   16px until `has-[>img:first-child]` fires, then 0px
 *   img  0px until `*:[img:first-child]:rounded-t-xl` fires, then 12px
 */
function cardOf(id: string): HTMLElement | null {
  const host = document.getElementById(id);
  if (!host) return null;
  return (host.shadowRoot?.querySelector('[data-slot="card"]') ??
    (host.matches('[data-slot="card"]') ? host : null)) as HTMLElement | null;
}

function imageOf(id: string): HTMLElement | null {
  const host = document.getElementById(id);
  return (host?.querySelector("img") ?? null) as HTMLElement | null;
}

function line(label: string, id: string): string {
  const card = cardOf(id);
  if (!card) return `${label}: (not mounted)`;
  const cs = getComputedStyle(card);
  const img = imageOf(id);
  const radius = img ? getComputedStyle(img).borderTopLeftRadius : "-";
  return (
    `${label}: pb ${cs.paddingBottom} | pt ${cs.paddingTop} | img radius ${radius}`
  );
}

setInterval(() => {
  const el = document.getElementById("card-stats");
  if (!el) return;
  el.textContent = [
    line("A2 slotted parts ", "a2"),
    line("A1 named slots   ", "a1"),
    line("B  class applier ", "b"),
  ].join("\n");
}, 100);
