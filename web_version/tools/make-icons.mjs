// Renders the app icons (icons/icon-192.png, icons/icon-512.png) from the game's own sprite code.
// Usage: npm run icons   (needs a local server on :8123 → `npm run serve` in another terminal)
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
import { writeFileSync } from 'node:fs';

const base = process.env.BASE_URL || 'http://localhost:8123';
const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto(`${base}/index.html?net=offline`);
for (const size of [192, 512]) {
  const dataUrl = await page.evaluate(async (size) => {
    const { getDino, getSprite } = await import('./js/dinos.js');
    const c = document.createElement('canvas');
    c.width = c.height = size;
    const g = c.getContext('2d');
    const grad = g.createLinearGradient(0, 0, size, size);
    grad.addColorStop(0, '#ff5f6d'); grad.addColorStop(0.5, '#ffc371'); grad.addColorStop(1, '#42e695');
    g.fillStyle = grad;
    g.fillRect(0, 0, size, size);
    g.fillStyle = 'rgba(0,0,0,.18)';
    g.fillRect(0, size * 0.74, size, size * 0.26);
    const s = getSprite(getDino('rex'), 'stand', 2, {});
    g.imageSmoothingEnabled = false;
    const k = Math.floor((size * 0.55) / s.h);
    const w = s.canvas.width * k, h = s.canvas.height * k;
    const x = (size - s.w * k) / 2 + s.ox * k + size * 0.03;
    const y = size * 0.74 - s.h * k + s.oy * k;
    g.drawImage(s.canvas, x, y, w, h);
    return c.toDataURL('image/png');
  }, size);
  writeFileSync(`www/icons/icon-${size}.png`, Buffer.from(dataUrl.split(',')[1], 'base64'));
  console.log(`wrote www/icons/icon-${size}.png`);
}
await browser.close();
