import { test, expect } from '@playwright/test';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

/**
 * The contract between the Elm wrappers and the custom elements, which
 * nothing else checks: the compiler sees neither side of it, and a wrong
 * variant name or a renamed event leaves a page that renders and misbehaves.
 *
 * The values are read out of the Elm sources rather than repeated here, so a
 * constructor added to `UI.Shadcn.Button` without a matching variant in the
 * vendored component fails this rather than shipping unstyled.
 */

const WRAPPERS = join(import.meta.dirname, '..', 'src', 'UI', 'Shadcn');

function elmSource(name: string): string {
  return readFileSync(join(WRAPPERS, `${name}.elm`), 'utf8');
}

/** The strings one encoder can produce. elm-format separates top-level
 * declarations with two blank lines, which is where the body ends. */
function encodedValues(source: string, encoder: string): string[] {
  const body = source.split(`\n${encoder} :`)[1]?.split('\n\n\n')[0] ?? '';
  const values = [...body.matchAll(/"([^"]+)"/g)].map((m) => m[1]);
  expect(values.length, `${encoder} produced no strings`).toBeGreaterThan(0);
  return values;
}

/** Renders an element with the given properties and returns its child's class. */
async function classFor(page, tag: string, props: Record<string, unknown>) {
  return page.evaluate(
    ({ tag, props }) => {
      const el = document.createElement(tag);
      Object.assign(el, props);
      document.body.appendChild(el);
      const className = el.firstElementChild?.className ?? '';
      el.remove();
      return className;
    },
    { tag, props }
  );
}

declare global {
  interface Window {
    /** Polls until `read` returns something. React renders on a microtask and
     * Base UI settles a frame after that, so a fixed wait is a flake. */
    __untilRendered: <T>(read: () => T | null) => Promise<T>;
  }
}

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await page.waitForFunction(() => customElements.get('shadcn-badge') !== undefined);
  await page.evaluate(() => {
    window.__untilRendered = async (read) => {
      const deadline = Date.now() + 5000;
      for (;;) {
        const value = read();
        if (value !== null && value !== undefined) return value;
        if (Date.now() > deadline) throw new Error('nothing rendered');
        await new Promise((r) => requestAnimationFrame(r));
      }
    };
  });
});

test('every element the wrappers render is registered', async ({ page }) => {
  const tags = new Set<string>();
  for (const file of readdirSync(WRAPPERS)) {
    for (const m of readFileSync(join(WRAPPERS, file), 'utf8').matchAll(/"(shadcn-[a-z-]+)"/g)) {
      tags.add(m[1]);
    }
  }
  expect(tags.size).toBeGreaterThan(0);
  const missing = await page.evaluate(
    (names) => names.filter((n) => customElements.get(n) === undefined),
    [...tags]
  );
  expect(missing).toEqual([]);
});

test('every badge variant Elm can send is one the component knows', async ({ page }) => {
  const unknown = await classFor(page, 'shadcn-badge', { label: 'x', variant: '__unknown__' });
  for (const variant of encodedValues(elmSource('Badge'), 'encodeVariant')) {
    expect(await classFor(page, 'shadcn-badge', { label: 'x', variant }), variant).not.toBe(unknown);
  }
});

test('every button variant and size Elm can send is one the component knows', async ({ page }) => {
  const source = elmSource('Button');
  const base = { label: 'x', shape: 'default', disabled: false };

  const unknownVariant = await classFor(page, 'shadcn-button', { ...base, variant: '__unknown__', size: 'default' });
  for (const variant of encodedValues(source, 'encodeVariant')) {
    expect(await classFor(page, 'shadcn-button', { ...base, variant, size: 'default' }), variant).not.toBe(unknownVariant);
  }

  const unknownSize = await classFor(page, 'shadcn-button', { ...base, variant: 'default', size: '__unknown__' });
  for (const size of encodedValues(source, 'encodeSize')) {
    expect(await classFor(page, 'shadcn-button', { ...base, variant: 'default', size }), size).not.toBe(unknownSize);
  }
});

test('a circular button rounds fully and a rectangular one does not', async ({ page }) => {
  const props = { label: 'x', variant: 'ghost', size: 'icon', disabled: false };
  expect(await classFor(page, 'shadcn-button', { ...props, shape: 'circle' })).toContain('rounded-full');
  expect(await classFor(page, 'shadcn-button', { ...props, shape: 'default' })).not.toContain('rounded-full');
});

test('a press reports the index Elm listens for', async ({ page }) => {
  const events = await page.evaluate(async () => {
    const seen: Array<[string, unknown]> = [];

    const button = document.createElement('shadcn-button');
    Object.assign(button, { label: 'press', variant: 'default', size: 'default', shape: 'default', disabled: false });
    button.addEventListener('button-press', (e) => seen.push(['button-press', (e as CustomEvent).detail]));
    document.body.appendChild(button);
    button.querySelector('button')!.click();

    const group = document.createElement('shadcn-button-group');
    (group as any).items = [
      { label: 'a', disabled: false },
      { label: 'b', disabled: false },
      { label: 'c', disabled: true },
    ];
    group.addEventListener('button-group-press', (e) => seen.push(['button-group-press', (e as CustomEvent).detail]));
    document.body.appendChild(group);
    const buttons = [...group.querySelectorAll('button')];
    buttons[1].click();
    // A disabled item reports nothing, so Elm never sees a press it disabled.
    buttons[2].click();

    button.remove();
    group.remove();
    return seen;
  });

  expect(events).toEqual([
    ['button-press', null],
    ['button-group-press', 1],
  ]);
});

test('the toggle group reports a selection and swallows a clearing press', async ({ page }) => {
  const events = await page.evaluate(async () => {
    const seen: unknown[] = [];
    const group = document.createElement('shadcn-toggle-group');
    (group as any).items = [
      { label: '1x', active: true, disabled: false },
      { label: '10x', active: false, disabled: false },
    ];
    group.addEventListener('toggle-group-press', (e) => seen.push((e as CustomEvent).detail));
    document.body.appendChild(group);

    const buttons = await window.__untilRendered(() => {
      const found = [...group.querySelectorAll('button')];
      return found.length === 2 ? found : null;
    });

    buttons[1].click();
    // Pressing what is already pressed would empty the group; Elm has no state
    // for "none", so nothing is reported.
    buttons[0].click();
    await window.__untilRendered(() => (seen.length > 0 ? seen : null));

    const pressed = buttons.map((b) => b.getAttribute('aria-pressed'));
    group.remove();
    return { seen, pressed };
  });

  expect(events.seen).toEqual([1]);
  expect(events.pressed).toEqual(['true', 'false']);
});

test('the slider reports a whole number', async ({ page }) => {
  const seen = await page.evaluate(async () => {
    const reported: unknown[] = [];
    const slider = document.createElement('shadcn-slider');
    Object.assign(slider, { min: 0, max: 100, value: 10 });
    slider.addEventListener('slider-change', (e) => reported.push((e as CustomEvent).detail));
    document.body.appendChild(slider);

    const input = await window.__untilRendered(
      () => slider.querySelector('input[type="range"]') as HTMLInputElement | null
    );
    // The range input is React's, so the value goes in through the prototype's
    // setter, the way the VRT helper drives the lap slider.
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!;
    setter.call(input, '42');
    input.dispatchEvent(new Event('input', { bubbles: true }));
    await window.__untilRendered(() => (reported.length > 0 ? reported : null));

    slider.remove();
    return reported;
  });

  expect(seen).toEqual([42]);
});

test('the card parts carry the slot their own classes match on', async ({ page }) => {
  const slots = await page.evaluate(() => {
    const card = document.createElement('shadcn-card');
    const footer = document.createElement('shadcn-card-footer');
    card.appendChild(footer);
    document.body.appendChild(card);
    const out = {
      cardSlot: card.getAttribute('data-slot'),
      footerSlot: footer.getAttribute('data-slot'),
      size: card.getAttribute('data-size'),
      // The footer's padding rule fires off the slot, from the card's classes.
      footerRule: card.className.includes('has-data-[slot=card-footer]'),
    };
    card.remove();
    return out;
  });

  expect(slots).toEqual({
    cardSlot: 'card',
    footerSlot: 'card-footer',
    size: 'default',
    footerRule: true,
  });
});
