// P5: actual exported Godot 4.7.2 in Chromium WebGL2 with v17 IndexedDB.
// There are two deliberately distinct claims:
// (1) a genuine fresh game Save button + browser reload, and
// (2) a seeded, engine-valid deep-Mesa snapshot replayed through actual
//     Godot E/WASD inputs, persisted and reloaded in Chromium.
// The *seeded* lower-gallery section is NOT a human blind full-world run.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');

const HOST = 'http://127.0.0.1:8765';
const SAVE_VERSION = 17;
const BOOT_MS = 5500;

async function inspectSave(page) {
  return page.evaluate(async () => {
    const all = await indexedDB.databases();
    const found = [];
    for (const info of all) {
      if (!info.name) continue;
      const db = await new Promise((resolve, reject) => {
        const q = indexedDB.open(info.name);
        q.onsuccess = () => resolve(q.result);
        q.onerror = () => reject(q.error);
      });
      for (const storeName of db.objectStoreNames) {
        const tx = db.transaction(storeName, 'readonly');
        const store = tx.objectStore(storeName);
        const keys = await new Promise((resolve, reject) => {
          const q = store.getAllKeys();
          q.onsuccess = () => resolve(q.result);
          q.onerror = () => reject(q.error);
        });
        for (const key of keys) {
          if (!String(key).includes('not_a_hero_save.json')) continue;
          const value = await new Promise((resolve, reject) => {
            const q = store.get(key);
            q.onsuccess = () => resolve(q.result);
            q.onerror = () => reject(q.error);
          });
          try {
            const payload = value?.contents ?? value?.data ?? value;
            const str = typeof payload === 'string' ? payload : new TextDecoder().decode(payload);
            found.push({db: info.name, store: storeName, key: String(key),
              snapshot: JSON.parse(str)});
          } catch (e) {
            found.push({db: info.name, store: storeName, key: String(key), error: String(e)});
          }
        }
      }
      db.close();
    }
    return {dbs: all.map(x => x.name), found};
  });
}

async function expectSave(page, description, predicate, timeout = 16000) {
  const end = Date.now() + timeout;
  let last = null;
  while (Date.now() < end) {
    last = await inspectSave(page);
    const match = last.found.find(x => x.snapshot?.version === SAVE_VERSION &&
      (!predicate || predicate(x.snapshot)));
    if (match) return match.snapshot;
    await page.waitForTimeout(450);
  }
  throw new Error(description + ': no matching v' + SAVE_VERSION +
    ' IndexedDB save. Last read: ' + JSON.stringify(last)?.slice(0, 1800));
}

async function launchGame(context, errors) {
  const page = await context.newPage();
  page.on('pageerror', e => errors.push('pageerror: ' + String(e)));
  page.on('console', m => {if (m.type() === 'error') errors.push('console: ' + m.text());});
  await page.goto(HOST + '/index.html', {waitUntil: 'domcontentloaded', timeout: 60000});
  await page.locator('canvas').waitFor({state: 'visible', timeout: 60000});
  await page.waitForTimeout(BOOT_MS);
  await page.locator('canvas').click({position: {x: 640, y: 355}});
  return page;
}

async function pressKey(page, key) {
  // The headless WASM software renderer can deliver only a handful of game
  // frames per second. A 160ms pulse intermittently falls between polls.
  await page.keyboard.down(key);
  await page.waitForTimeout(500);
  await page.keyboard.up(key);
  await page.waitForTimeout(850);
}

async function walk(page, keys, milliseconds) {
  for (const key of keys) await page.keyboard.down(key);
  await page.waitForTimeout(milliseconds);
  for (const key of [...keys].reverse()) await page.keyboard.up(key);
  await page.waitForTimeout(250);
}

async function saveUsingButton(page) {
  await page.mouse.click(1200, 38); // Godot CanvasLayer/SaveButton, not a DOM mock.
  await page.waitForTimeout(1100);
}

async function waitForLiveEngine(page, fixture, description) {
  // Seeing a Canvas is not proof that Godot's WASM, Main scene and IDBFS
  // restore have finished. An unmodified fixture already exists in IndexedDB.
  // Require a NEW in-game Save button write with a strictly advanced
  // simulation clock compared to the injected fixture.
  const elapsed = fixture.ecology.elapsed_minutes;
  for (let attempt = 0; attempt < 14; attempt++) {
    await saveUsingButton(page);
    const found = await inspectSave(page);
    const current = found.found.find(x => x.snapshot?.version === SAVE_VERSION)?.snapshot;
    if (current?.current_level === fixture.current_level &&
        current.ecology.elapsed_minutes > elapsed + 0.5 &&
        current.mesa?.depth_open === fixture.mesa.depth_open) {
      console.log('Engine-ready scene/IDBFS heartbeat:', description,
        {elapsedBefore: elapsed, elapsedNow: current.ecology.elapsed_minutes, attempt});
      return current;
    }
    await page.waitForTimeout(800);
  }
  throw new Error(description + ': canvas shown but Godot scene did not save a fresh world-clock tick');
}

function seededLowerGallery(fresh) {
  // Generate fixture from a real browser-produced v17 snapshot rather than
  // inventing the other versioned fields. Only the authored, validated manual
  // path and starting level/position are set. Nothing is pre-observed.
  const state = structuredClone(fresh);
  Object.assign(state, {
    current_level: 'mesa_depth',
    mesa_position: [1110, 264],
    mesa_depth_position: [590, 344],
  });
  Object.assign(state.mesa, {
    inspected: true, manual_progress: 3, access_method: 'manual',
    first_sector_safe: true,
    power_progress: 2, power_method: 'manual',
    flow_progress: 2, flow_method: 'manual',
    depth_open: true,
    depth_archive_read: false, depth_warm: false,
  });
  state.notebook = {observed: [], pinned: ''};
  return state;
}

async function overwritePersistedSaveFromSeedPage(context, snapshot) {
  // Emscripten's IDBFS is already mounted by a running Godot instance.
  // Shut the game page FIRST; then modify its exact saved-file record from a
  // separate same-origin *test-only* HTML page. This avoids a live engine's
  // delayed FS.syncfs overwriting the prepared fixture before the next boot.
  const page = await context.newPage();
  await page.goto(HOST + '/__test_seed__.html');
  const result = await page.evaluate(async state => {
    const dbNames = await indexedDB.databases();
    for (const info of dbNames) {
      if (!info.name) continue;
      const db = await new Promise((resolve, reject) => {
        const q = indexedDB.open(info.name);
        q.onsuccess = () => resolve(q.result);
        q.onerror = () => reject(q.error);
      });
      for (const storeName of db.objectStoreNames) {
        const scan = db.transaction(storeName, 'readonly').objectStore(storeName);
        const keys = await new Promise((resolve, reject) => {
          const q = scan.getAllKeys();
          q.onsuccess = () => resolve(q.result);
          q.onerror = () => reject(q.error);
        });
        for (const key of keys) {
          if (!String(key).includes('not_a_hero_save.json')) continue;
          const record = await new Promise((resolve, reject) => {
            const q = db.transaction(storeName, 'readonly').objectStore(storeName).get(key);
            q.onsuccess = () => resolve(q.result);
            q.onerror = () => reject(q.error);
          });
          if (!record || typeof record !== 'object' || !('contents' in record)) {
            throw new Error('Unexpected Godot IDBFS record shape at ' + key);
          }
          record.contents = new TextEncoder().encode(JSON.stringify(state));
          record.timestamp = new Date();
          await new Promise((resolve, reject) => {
            const tx = db.transaction(storeName, 'readwrite');
            tx.objectStore(storeName).put(record, key);
            tx.oncomplete = resolve;
            tx.onerror = () => reject(tx.error);
            tx.onabort = () => reject(tx.error);
          });
          db.close();
          return {database: info.name, store: storeName, key: String(key),
            bytes: record.contents.byteLength};
        }
      }
      db.close();
    }
    throw new Error('No saved v17 IDBFS key found for fixture injection');
  }, snapshot);
  await page.close();
  console.log('Prepared lower-level fixture:', JSON.stringify(result));
}

(async () => {
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--enable-webgl', '--use-gl=angle',
      '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  });
  const errors = [];
  const context = await browser.newContext({viewport: {width: 1280, height: 720}});
  let page;
  try {
    page = await launchGame(context, errors);
    assert(await page.evaluate(() => !!document.createElement('canvas').getContext('webgl2')),
      'Actual browser lacks WebGL2');
    await page.screenshot({path: '/tmp/nah-fresh-nest.png'});

    // Actual new game: move in the original home and use its Save button.
    await walk(page, ['d'], 1300);
    await saveUsingButton(page);
    const fresh = await expectSave(page, 'Fresh Little Nest Save', s =>
      s.current_level === 'shelter' && s.shelter_position?.[0] > 360);
    assert.equal(fresh.version, SAVE_VERSION);
    console.log('PASS: actual fresh v17 Little Nest save/movement', fresh.shelter_position);
    await page.reload({waitUntil: 'domcontentloaded', timeout: 60000});
    await page.waitForTimeout(BOOT_MS);
    await saveUsingButton(page);
    const returned = await expectSave(page, 'Reloaded Little Nest', s =>
      s.current_level === 'shelter' && s.shelter_position?.[0] > 360);
    assert.equal(returned.version, SAVE_VERSION);
    await page.screenshot({path: '/tmp/nah-nest-reload.png'});
    console.log('PASS: real Chromium fresh-game IndexedDB page reload');

    // Physically deeper content would require a lengthy real navigation route.
    // Seed ONLY the entry-state using the versioned state record while Godot
    // isn't running, then execute the *real* scenes, controls and further saves.
    await page.close();
    const lowerFixture = seededLowerGallery(returned);
    await overwritePersistedSaveFromSeedPage(context, lowerFixture);
    page = await launchGame(context, errors);
    const atArchive = await waitForLiveEngine(page, lowerFixture, 'Seeded lower archive');
    assert.deepEqual(atArchive.notebook.observed, [], 'Unobserved secrets leaked at boot');
    await page.screenshot({path: '/tmp/nah-depth-cold.png'});

    // Genuine E observes the physical archive while Yuna stands by it.
    await page.locator('canvas').click({position: {x: 640, y: 350}});
    await pressKey(page, 'e');
    const observed = await expectSave(page, 'Real E at lower archive', s =>
      s.mesa.depth_archive_read && s.notebook.observed.includes('mesa_thermal_archive'));
    assert.equal(observed.current_level, 'mesa_depth');
    console.log('PASS: actual WebGL2 lower-gallery E discovered only witnessed archive');

    // CI Chromium SwiftShader is too slow/unpredictable for a long
    // keyboard-pathfinding test: the native engine scene suite already
    // proves real physical walking, collision and path. For this browser
    // acceptance test, seed a second VALID saved standing position via
    // IndexedDB only while the Godot game is not running. All actual archive
    // and regulator actions remain real E input inside the exported game.
    await page.close();
    const regulatorFixture = {
      ...observed, mesa_depth_position: [415, 390],
    };
    await overwritePersistedSaveFromSeedPage(context, regulatorFixture);
    page = await launchGame(context, errors);
    const approached = await waitForLiveEngine(page, regulatorFixture, 'Lower regulator');
    assert(approached.mesa.depth_archive_read && !approached.mesa.depth_warm &&
      approached.notebook.observed.includes('mesa_thermal_archive'),
      'Witnessed log lost while restoring regulator scene');
    assert(Math.hypot(approached.mesa_depth_position[0] - 415,
      approached.mesa_depth_position[1] - 390) < 62,
      'Regulator waypoint invalid in real WebGL2 level');
    await page.locator('canvas').click({position: {x: 640, y: 350}});
    await pressKey(page, 'e');
    const warmed = await expectSave(page, 'Real E warm regulator', s =>
      s.current_level === 'mesa_depth' && s.mesa.depth_warm &&
      s.mesa.depth_archive_read && s.notebook.observed.includes('mesa_thermal_archive'));
    await page.screenshot({path: '/tmp/nah-depth-warm.png'});
    console.log('PASS: real lower-gallery archive E, regulator E, physical warmth and IndexedDB Save (waypoints seeded)');

    await page.reload({waitUntil: 'domcontentloaded', timeout: 60000});
    await page.waitForTimeout(BOOT_MS);
    await saveUsingButton(page);
    const reloaded = await expectSave(page, 'v17 lower-gallery reload', s =>
      s.current_level === 'mesa_depth' && s.mesa.depth_warm &&
      s.mesa.depth_archive_read && s.notebook.observed.includes('mesa_thermal_archive'));
    assert(Math.abs(reloaded.mesa_depth_position[0] - warmed.mesa_depth_position[0]) < 12,
      'Lower level position was lost on reload');
    await page.screenshot({path: '/tmp/nah-depth-warm-reload.png'});

    // Physically leave through the lower service lift, then assert the intact
    // separate upstairs level and retained warmth through another real save.
    // A final second-floor WAYPOINT fixture focuses the lift only. This
    // isolates browser event/save/scene-transition correctness from slow
    // renderer-dependent multi-minute movement (tested in real Godot scenes).
    await page.close();
    const returnFixture = {
      ...reloaded, mesa_depth_position: [125, 493],
    };
    await overwritePersistedSaveFromSeedPage(context, returnFixture);
    page = await launchGame(context, errors);
    const atExit = await waitForLiveEngine(page, returnFixture, 'Lower return lift');
    assert(Math.hypot(atExit.mesa_depth_position[0] - 125,
      atExit.mesa_depth_position[1] - 493) < 4, 'Return waypoint did not restore');
    assert(atExit.mesa.depth_archive_read, 'Warm saved archive was lost before exit');
    await page.screenshot({path: '/tmp/nah-depth-exit-ready.png'});
    await page.locator('canvas').click({position: {x: 640, y: 355}});
    await page.waitForTimeout(500);
    await pressKey(page, 'e');
    await saveUsingButton(page);
    const upstairs = await expectSave(page, 'Real E from depth to main Mesa', s =>
      s.current_level === 'mesa' && s.mesa.depth_warm && s.mesa.depth_open);
    assert(upstairs.mesa_position[0] > 1000, 'Mesa upper gallery return moved Yuna elsewhere');
    await page.screenshot({path: '/tmp/nah-mesa-return.png'});
    console.log('PASS: Chromium v17 lower room Save/Reload, waypointed actual E return, intact upper Mesa');

    // P0-P5 browser boot and input errors invalidate the result.
    assert.equal(errors.length, 0, 'Chromium/Godot console errors: ' + JSON.stringify(errors));
    console.log('PASS: Chromium WebGL2 fresh v17 + lower v17 archive/heat + waypointed real E return + IndexedDB persistent reload');
  } finally {
    if (errors.length) console.log('Browser errors:', JSON.stringify(errors));
    await browser.close();
  }
})().catch(err => {console.error(err); process.exitCode = 1;});
