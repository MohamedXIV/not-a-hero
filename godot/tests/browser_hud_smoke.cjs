// P5a: real Godot 4.7.2 HTML5 canvas, Chromium WebGL2, responsive HUD.
// Unlike a pure GDScript geometry test, this drives actual DOM canvas input
// after window resizes and captures real renderer frames. Screenshot
// differences establish UI responses, not artistic quality/legibility approval.
const {chromium} = require('playwright');
const {PNG} = require('pngjs');
const assert = require('node:assert/strict');

const HOST = 'http://127.0.0.1:8765';
const SIZES = [{width: 1280, height: 720}, {width: 960, height: 540},
  {width: 640, height: 360}];
const SAVE_VERSION = 17;

function sampleDifference(a, b, box) {
  const first = PNG.sync.read(a);
  const second = PNG.sync.read(b);
  assert.equal(first.width, second.width, 'Screenshot widths differ');
  assert.equal(first.height, second.height, 'Screenshot heights differ');
  const x0 = Math.floor(first.width * box.x0);
  const y0 = Math.floor(first.height * box.y0);
  const x1 = Math.floor(first.width * box.x1);
  const y1 = Math.floor(first.height * box.y1);
  let changed = 0;
  let total = 0;
  for (let y = y0; y < y1; y += 2) {
    for (let x = x0; x < x1; x += 2) {
      const i = (y * first.width + x) * 4;
      const magnitude = Math.abs(first.data[i] - second.data[i]) +
        Math.abs(first.data[i + 1] - second.data[i + 1]) +
        Math.abs(first.data[i + 2] - second.data[i + 2]);
      if (magnitude > 72) changed++;
      total++;
    }
  }
  return changed / total;
}

async function saveRecords(page) {
  return page.evaluate(async () => {
    const found = [];
    for (const entry of await indexedDB.databases()) {
      if (!entry.name) continue;
      const db = await new Promise((resolve, reject) => {
        const r = indexedDB.open(entry.name);
        r.onsuccess = () => resolve(r.result);
        r.onerror = () => reject(r.error);
      });
      for (const name of db.objectStoreNames) {
        const tx = db.transaction(name, 'readonly');
        const keys = await new Promise((resolve, reject) => {
          const r = tx.objectStore(name).getAllKeys();
          r.onsuccess = () => resolve(r.result);
          r.onerror = () => reject(r.error);
        });
        for (const key of keys) {
          if (!String(key).includes('not_a_hero_save.json')) continue;
          const value = await new Promise((resolve, reject) => {
            const r = db.transaction(name, 'readonly').objectStore(name).get(key);
            r.onsuccess = () => resolve(r.result);
            r.onerror = () => reject(r.error);
          });
          const bytes = value?.contents ?? value?.data ?? value;
          try {
            const text = typeof bytes === 'string' ? bytes : new TextDecoder().decode(bytes);
            found.push(JSON.parse(text));
          } catch (err) {
            throw new Error('Corrupt IndexedDB Godot save: ' + String(err));
          }
        }
      }
      db.close();
    }
    return found;
  });
}

async function assertSaveFromRealCanvas(page, previousClock, dimension) {
  const canvas = page.locator('canvas');
  const bounds = await canvas.boundingBox();
  assert(bounds && bounds.width > 0 && bounds.height > 0, 'Invisible game canvas');
  // Actual Godot CanvasLayer Save button, not a DOM control or F6 shortcut.
  // Top-right in the resized 16:9 game view; both large and compact layouts.
  const pos = {x: bounds.width - 54, y: bounds.height * 0.052};
  await canvas.click({position: pos});
  for (let attempt = 0; attempt < 20; attempt++) {
    await page.waitForTimeout(450);
    const found = await saveRecords(page);
    const state = found.find(x => x.version === SAVE_VERSION &&
      x.current_level === 'shelter' &&
      x.ecology.elapsed_minutes > previousClock + 0.001);
    if (state) {
      console.log('PASS: in-game Save button and live IndexedDB at',
        dimension.width + 'x' + dimension.height, 'clock', state.ecology.elapsed_minutes);
      return state.ecology.elapsed_minutes;
    }
  }
  throw new Error('Save button/IDBFS did not update at ' +
    dimension.width + 'x' + dimension.height);
}

async function pressKey(page, key) {
  await page.keyboard.down(key);
  await page.waitForTimeout(500);
  await page.keyboard.up(key);
  await page.waitForTimeout(700);
}

async function screenshot(page, size, suffix) {
  const name = '/tmp/nah-hud-' + size.width + 'x' + size.height + '-' + suffix + '.png';
  const shot = await page.locator('canvas').screenshot({path: name});
  return shot;
}

(async () => {
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--enable-webgl', '--use-gl=angle',
      '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  });
  const errors = [];
  const ctx = await browser.newContext({viewport: SIZES[0]});
  const page = await ctx.newPage();
  page.on('pageerror', e => errors.push('pageerror: ' + String(e)));
  page.on('console', m => {
    if (m.type() === 'error') errors.push('console: ' + m.text());
  });
  try {
    await page.goto(HOST + '/index.html', {waitUntil: 'domcontentloaded', timeout: 60000});
    await page.locator('canvas').waitFor({state: 'visible', timeout: 60000});
    assert(await page.evaluate(() => !!document.createElement('canvas').getContext('webgl2')),
      'Chromium lacks real WebGL2');
    await page.waitForTimeout(6500);
    let clock = -1;

    for (const size of SIZES) {
      await page.setViewportSize(size);
      await page.waitForTimeout(1600);
      const bounds = await page.locator('canvas').boundingBox();
      assert(bounds, 'Canvas missing after resize');
      assert(bounds.width <= size.width + 1 && bounds.height <= size.height + 1,
        'Canvas escaped Chromium viewport at ' + size.width + 'x' + size.height);
      assert(bounds.width > size.width * 0.90 && bounds.height > size.height * 0.90,
        'Letterboxed or collapsed canvas at ' + size.width + 'x' + size.height);

      await page.locator('canvas').click({
        position: {x: bounds.width * 0.5, y: bounds.height * 0.48},
      });
      // Real keyboard actions on the same running game instance, after resize.
      const closed = await screenshot(page, size, 'closed');
      await pressKey(page, 'n');
      const notebook = await screenshot(page, size, 'notebook');
      await pressKey(page, 'h');
      const controls = await screenshot(page, size, 'controls');
      await pressKey(page, 'Tab');
      const condition = await screenshot(page, size, 'condition');
      await pressKey(page, 'Tab');
      const closedAgain = await screenshot(page, size, 'closed-again');

      // Compare inside the same central reading area. Discriminates rendered
      // panel presence from browser DOM key events that never reached Godot.
      const center = {x0: 0.16, y0: 0.30, x1: 0.84, y1: 0.87};
      const openDiff = sampleDifference(closed, notebook, center);
      const swap1 = sampleDifference(notebook, controls, center);
      const swap2 = sampleDifference(controls, condition, center);
      const closeDiff = sampleDifference(condition, closedAgain, center);
      console.log('HUD real-frame changes', size.width + 'x' + size.height,
        {openDiff, swap1, swap2, closeDiff});
      assert(openDiff > 0.07, 'Notebook did not visibly open');
      assert(swap1 > 0.0015, 'H did not visibly replace the Notebook');
      assert(swap2 > 0.0015, 'Tab did not visibly replace Controls');
      assert(closeDiff > 0.07, 'Second Tab did not visibly close Condition');

      clock = await assertSaveFromRealCanvas(page, clock, size);
      console.log('PASS: live Chromium WebGL2 HUD, N/H/Tab and Save at',
        size.width + 'x' + size.height);
    }
    assert.deepEqual(errors, [], 'Chromium/Godot errors');
    console.log('PASS: Chromium WebGL2 real HUD resize 1280x720 + 960x540 + 640x360, overlays and IndexedDB Save');
  } finally {
    if (errors.length) console.log('Browser errors:', JSON.stringify(errors));
    await browser.close();
  }
})().catch(err => {console.error(err); process.exitCode = 1;});
