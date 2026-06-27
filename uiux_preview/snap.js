const { chromium } = require('/root/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const fs = require('fs');
const path = require('path');

const OUT_DIR = '/workspace/uiux_preview/screenshots';
fs.mkdirSync(OUT_DIR, { recursive: true });

const URL = 'http://localhost:8123/';

const SHOTS = [
  ['00-full',          1440, 3200, null,         true],
  ['01-masthead',      1440,  900, '.masthead',  false],
  ['02-ch1-pair',      1440, 1300, '#ch1 .pair', false],
  ['03-ch1-doctile',   1440,  900, '#ch1 .component-block', false],
  ['04-ch2-pair',      1440, 1500, '#ch2 .pair', false],
  ['05-ch2-toc',       1440,  900, '#ch2 .component-block', false],
  ['06-ch3-pair',      1440, 1500, '#ch3 .pair', false],
  ['07-ch4-glass',     1440,  700, '#ch4 .component-canvas', false],
  ['08-ch5-type',      1440,  800, '#ch5 .component-block', false],
  ['09-ch6-color',     1440,  900, '#ch6 .component-block', false],
  // mobile-size captures for phone-pair blocks
  ['m1-library',        900, 1300, '#ch1 .pair',  false],
  ['m2-reader',         900, 1500, '#ch2 .pair',  false],
  ['m3-settings',       900, 1500, '#ch3 .pair',  false],
];

(async () => {
  const browser = await chromium.launch();
  for (const [name, w, h, sel, full] of SHOTS) {
    const ctx = await browser.newContext({
      viewport: { width: w, height: h },
      deviceScaleFactor: 2,
    });
    const page = await ctx.newPage();
    await page.goto(URL, { waitUntil: 'networkidle' });
    await page.waitForTimeout(900);
    if (sel) {
      const el = await page.$(sel);
      if (!el) {
        console.log(`  ! selector not found: ${sel}`);
      } else {
        await el.scrollIntoViewIfNeeded();
        await page.waitForTimeout(200);
        await el.screenshot({ path: path.join(OUT_DIR, `${name}.png`) });
        console.log(`  ✓ ${name}.png`);
      }
    } else {
      await page.screenshot({ path: path.join(OUT_DIR, `${name}.png`), fullPage: full });
      console.log(`  ✓ ${name}.png (full)`);
    }
    await ctx.close();
  }
  await browser.close();
  console.log('DONE');
})();
