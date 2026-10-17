// Real Chromium WebGL2 smoke for the exported Godot build.
// Only used by the narrowly scoped PR browser validation workflow.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');

async function findGodotSave(page) {
  return page.evaluate(async () => {
    const all = await indexedDB.databases();
    const found = [];
    for (const info of all) {
      if (!info.name) continue;
      const db = await new Promise((resolve, reject) => {
        const request = indexedDB.open(info.name);
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      for (const name of db.objectStoreNames) {
        const tx = db.transaction(name, 'readonly');
        const store = tx.objectStore(name);
        const [keys, values] = await Promise.all([
          new Promise((resolve, reject) => {
            const request = store.getAllKeys();
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
          }),
          new Promise((resolve, reject) => {
            const request = store.getAll();
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
          }),
        ]);
        for (let i = 0; i < keys.length; i++) {
          const key = String(keys[i]);
          if (!key.includes('not_a_hero_save.json')) continue;
          const record = values[i];
          const bytes = record?.contents || record?.data || record;
          let text = '';
          try {
            text = typeof bytes === 'string' ? bytes : new TextDecoder().decode(bytes);
            found.push({db: info.name, store: name, key, snapshot: JSON.parse(text)});
          } catch (e) {
            found.push({db: info.name, store: name, key, error: String(e)});
          }
        }
      }
      db.close();
    }
    return {databases: all.map(item => item.name), matchingSaves: found};
  });
}

async function waitForSave(page) {
  for (let i = 0; i < 20; i++) {
    const result = await findGodotSave(page);
    if (result.matchingSaves.some(x => x.snapshot?.version === 1)) return result;
    await page.waitForTimeout(500);
  }
  return findGodotSave(page);
}

(async () => {
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--enable-webgl', '--use-gl=angle',
           '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  });
  const context = await browser.newContext({viewport: {width: 1280, height: 720}});
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (message.type() === 'error') errors.push(message.text());
  });
  try {
    await page.goto('http://127.0.0.1:8765/index.html', {waitUntil: 'domcontentloaded', timeout: 60_000});
    await page.locator('canvas').waitFor({state: 'visible', timeout: 60_000});
    assert(await page.evaluate(() => !!document.createElement('canvas').getContext('webgl2')),
           'Browser has no WebGL2 context');
    await page.waitForTimeout(6000);
    await page.locator('canvas').click({position:{x:640,y:350}});
    // Move *within the shelter* before any autosave can occur. This isolates
    // the actual Save button rather than incidentally passing on an E transition.
    await page.keyboard.down('d');
    await page.waitForTimeout(1800);
    await page.keyboard.up('d');
    await page.waitForTimeout(450);
    await page.mouse.click(1200, 38);
    await page.waitForTimeout(2500);
    const saved = await waitForSave(page);
    console.log('IndexedDB before reload:', JSON.stringify(saved));
    const snapshot = saved.matchingSaves.find(x => x.snapshot?.version === 1)?.snapshot;
    assert(snapshot, 'No persisted user:// JSON save found in IndexedDB');
    assert.equal(snapshot.current_level, 'shelter', 'Saved initial shelter unexpectedly changed scenes');
    assert(snapshot.shelter_position?.[0] > 380,
           'Save button did not persist new shelter position; got ' +
           JSON.stringify(snapshot.shelter_position));
    await page.screenshot({path: '/tmp/nah-before-reload.png'});
    await page.reload({waitUntil: 'domcontentloaded', timeout: 60_000});
    await page.waitForTimeout(6000);
    const restored = await waitForSave(page);
    console.log('IndexedDB after reload:', JSON.stringify(restored));
    const persisted = restored.matchingSaves.find(x => x.snapshot?.version === 1)?.snapshot;
    assert(persisted, 'Save disappeared from IndexedDB after browser reload');
    assert.equal(persisted.current_level, 'shelter');
    assert(persisted.shelter_position[0] > 380,
           'Saved position missing after page reload');
    await page.screenshot({path: '/tmp/nah-after-reload.png'});
    assert.equal(errors.length, 0, 'Browser JavaScript/console errors: ' + JSON.stringify(errors));
    console.log('PASS: real Chromium WebGL2 boot, in-shelter movement, Save button, IndexedDB snapshot and browser reload persistence');
  } finally {
    if (errors.length) console.log('Browser console errors:', JSON.stringify(errors));
    await browser.close();
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
