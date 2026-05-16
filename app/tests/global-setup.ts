import { chromium, FullConfig, Page } from '@playwright/test';

const WARMUP_PATHS = ['/', '/wec/2025/le_mans_24h'];
const WARMUP_TIMEOUT = 30_000;
const RETRY_LIMIT = 2;
const RETRY_DELAY = 2_000;

async function warmUpRoute(page: Page, url: string) {
  let lastError: unknown;
  for (let attempt = 1; attempt <= RETRY_LIMIT; attempt++) {
    try {
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: WARMUP_TIMEOUT });
      return;
    } catch (error) {
      lastError = error;
      console.warn(`[global-setup] warmup failed (attempt ${attempt}/${RETRY_LIMIT}) for ${url}`);
      await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY));
    }
  }
  throw lastError;
}

async function globalSetup(config: FullConfig) {
  const baseURL = config.projects[0].use?.baseURL;
  if (!baseURL) throw new Error('baseURL is not configured');

  const browser = await chromium.launch();
  const page = await browser.newPage();
  for (const path of WARMUP_PATHS) {
    await warmUpRoute(page, `${baseURL}${path}`);
  }
  await browser.close();
}

export default globalSetup;
