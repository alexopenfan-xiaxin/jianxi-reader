import asyncio
import os
from playwright.async_api import async_playwright

OUT_DIR = "/workspace/uiux_preview/screenshots"
os.makedirs(OUT_DIR, exist_ok=True)

URL = "http://localhost:8123/"

# We will use a wide viewport (1440) and full-page screenshot
# Plus component-specific captures
SHOTS = [
    # (filename, viewport, selector, full_page, extra_action)
    ("00-full", (1440, 3000), None, True, None),
    ("01-masthead", (1440, 900), ".masthead", False, None),
    ("02-ch1-library-pair", (1440, 1300), "#ch1 .pair", False, None),
    ("03-ch1-doctile-component", (1440, 900), "#ch1 .component-block", False, None),
    ("04-ch2-reader-pair", (1440, 1500), "#ch2 .pair", False, None),
    ("05-ch2-toc-component", (1440, 900), "#ch2 .component-block", False, None),
    ("06-ch3-settings-pair", (1440, 1500), "#ch3 .pair", False, None),
    ("07-ch4-liquid-glass", (1440, 700), "#ch4 .component-canvas", False, None),
    ("08-ch5-typography", (1440, 800), "#ch5 .component-block", False, None),
    ("09-ch6-color-palette", (1440, 900), "#ch6 .component-block", False, None),
]

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        for filename, (w, h), selector, full_page, _ in SHOTS:
            ctx = await browser.new_context(viewport={"width": w, "height": h}, device_scale_factor=2)
            page = await ctx.new_page()
            await page.goto(URL, wait_until="networkidle")
            # wait for fonts
            await page.wait_for_timeout(800)
            if selector:
                el = await page.query_selector(selector)
                if not el:
                    print(f"  ! selector not found: {selector}")
                else:
                    await el.scroll_into_view_if_needed()
                    await page.wait_for_timeout(200)
                    await el.screenshot(path=f"{OUT_DIR}/{filename}.png")
                    print(f"  ✓ {filename}.png")
            else:
                await page.screenshot(path=f"{OUT_DIR}/{filename}.png", full_page=full_page)
                print(f"  ✓ {filename}.png (full page)")
            await ctx.close()
        await browser.close()

asyncio.run(main())
print("DONE")
