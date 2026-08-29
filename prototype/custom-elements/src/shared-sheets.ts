/**
 * The page's stylesheets, copied once into constructed sheets so every shadow
 * root can adopt the same objects. Tailwind's utilities live in the document,
 * and anything React renders inside a shadow root is out of their reach
 * without this.
 */
let pageSheets: CSSStyleSheet[] | null = null;

export function sharedSheets(): CSSStyleSheet[] {
  if (pageSheets) return pageSheets;
  pageSheets = [];
  for (const sheet of document.styleSheets) {
    let rules: CSSRuleList;
    try {
      rules = sheet.cssRules;
    } catch {
      // A cross-origin sheet (the Google Fonts import) cannot be read; the
      // shadow tree does not need it, so skip rather than fail.
      continue;
    }
    const copy = new CSSStyleSheet();
    copy.replaceSync(Array.from(rules, (r) => r.cssText).join("\n"));
    pageSheets.push(copy);
  }
  return pageSheets;
}
