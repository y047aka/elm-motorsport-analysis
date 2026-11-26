import { test, expect } from '@playwright/test';
import { existsSync } from 'node:fs';

import { readSource } from './helpers';

/**
 * A logo the manufacturer table names is a file Vite serves out of `app/public`.
 * The build reads the table's shape and nothing more, so a path to no file draws the car without its logo and fails nothing; nothing needs a browser.
 */

type Table = { manufacturers: { name: string; logo?: string }[] };

test('every logo the manufacturer table names is a file the app serves', () => {
  const table: Table = JSON.parse(readSource('data/wec/manufacturers.json'));

  for (const { name, logo } of table.manufacturers) {
    if (logo === undefined) continue;

    expect(logo, `${name}: a logo is a path from the site root`).toMatch(/^\//);
    expect(
      existsSync(new URL(`../public${logo}`, import.meta.url)),
      `${name}: ${logo} is not under app/public`,
    ).toBe(true);
  }
});
