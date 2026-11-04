// Smoke test for the Godot web export: serves the build locally and loads it in
// headless Chrome twice: as a desktop browser (1280x720) and as a phone held in landscape
// (844x390 at 3x, touch, mobile). Each run fails on any failed request, HTTP error, page
// error, console error, missing engine boot log, the title not arriving ("[Game] Arrived
// at TITLE"), a still-visible Godot status overlay, a missing canvas, a page whose
// touch/selection CSS is not applied, or a screenshot with nothing drawn. Then it plays
// wing 1 with the mouse (desktop) or CDP touches with id 7 (phone; iOS Safari's touch ids
// are never 0), tapping where each room logs its layout ("[Room] Easel at ...", "[Room]
// Masterpiece at ...", "[Room] Door to N at ...", N -1 for the exit): tap the title's play
// button where it logs itself ("[Title] Play button at ..."), then in the hub wing 1's
// door where it logs itself ("[Hub] Wing door 1 at ... (open, 0 star(s))"), require "[Game]
// Arrived at ROOM" (the foyer, no guard), tap the easel and drag along every ghost stroke the canvas
// logs ("[Forgery] Ghosts in base units ...") until "[Room] Fake ready"; through the door
// to room 1 (the hall: hide in its middle portrait at once, wait for the corridor guard to turn
// at the far door, "[Guard] Guard reaches waypoint 1", and to come back past, then step out
// and through its door to room 2); in the gallery go low round the right, tilt the far frame
// ("[Room] Tilted the frame") to lure the sentry off the swap spot, step aside, and tap the
// masterpiece until "[Room] Swapped"; back into the hall (hide in its far portrait at once,
// step out once the guard turns at the far door) to the foyer and tap its exit until "[Room]
// Escaped", require "[Results] Stars", tap home and require the hub to show wing 1's
// stars and wing 2's door open. World points (rooms and the hub log base units of the
// 960x540 world) are shifted by the world's offset on screen ("[Game] Screen fit: ...
// world at (x, y)": the world is centred on the safe area of a wider screen). A catch
// ("[Room] Caught") is waited out until the mime is back at the entrance, then the tap (or
// the room's whole sequence) is repeated, at most ATTEMPTS times.
// Usage: node tools/smoke_web.mjs [buildDir]   (default: build/web)
// Env:   SMOKE_BOOT_TIMEOUT_MS (default 30000), SMOKE_SETTLE_MS (default 2000),
//        SMOKE_STEP_TIMEOUT_MS (each waited-for log line, default 20000)
// Screenshots (next to buildDir): build/smoke-<run>.png (the title),
// build/smoke-<run>-results.png (the results overlay) and build/smoke-<run>-hub.png (the hub
// after wing 1).
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { launchChrome, serveBuild } from './web_util.mjs';

const repoRoot = resolve(fileURLToPath(import.meta.url), '..', '..');
const buildDir = resolve(process.argv[2] ?? join(repoRoot, 'build', 'web'));
const bootTimeoutMs = Number(process.env.SMOKE_BOOT_TIMEOUT_MS ?? 30000);
const settleMs = Number(process.env.SMOKE_SETTLE_MS ?? 2000);
const STEP_TIMEOUT_MS = Number(process.env.SMOKE_STEP_TIMEOUT_MS ?? 20000);

const PHONE = { deviceScaleFactor: 3, hasTouch: true, isMobile: true };
const RUNS = [
  { name: 'desktop', context: { viewport: { width: 1280, height: 720 } } },
  { name: 'mobile-landscape', context: { viewport: { width: 844, height: 390 }, ...PHONE } },
];

// Set by html/head_include in export_presets.cfg so pull-to-refresh, double-tap zoom,
// text selection and long-press menus never fire. -webkit-touch-callout is iOS-only and
// Chrome does not compute it; test_gameplay.gd checks it is in the preset's head_include.
const TOUCH_CSS = { touchAction: 'none', overscrollBehavior: 'none', userSelect: 'none' };
// project.godot base viewport (aspect expand: the visible area grows on one axis from (0, 0)).
const BASE = { width: 960, height: 540 };
const RECT = '\\[P: \\(([\\d.-]+), ([\\d.-]+)\\), S: \\(([\\d.-]+), ([\\d.-]+)\\)\\]';
const PLAY_RECT = new RegExp(`^\\[Title\\] Play button at ${RECT}`);
const WORLD_AT = /^\[Game\] Screen fit: .* world at \(([\d.-]+), ([\d.-]+)\)/;
// "[Hub] Wing door N at (x, y) (open|locked|broken, K star(s))".
const wingDoorLog = (n) => new RegExp(`^\\[Hub\\] Wing door ${n} at \\(([\\d.-]+), ([\\d.-]+)\\) \\((\\w+), (\\d) star`);
// A tap on a wing door's painting, above its floor spot, means the door.
const WING_DOOR_TAP_Y = -60;
const MASTERPIECE_RECT = new RegExp(`^\\[Room\\] Masterpiece at ${RECT}`);
// "[Room] Door to N at (x, y)": the door's spot, N the room it leads to (-1: the exit).
const doorLog = (to) => new RegExp(`^\\[Room\\] Door to ${to} at \\(([\\d.-]+), ([\\d.-]+)\\)`);
const EASEL_RECT = new RegExp(`^\\[Room\\] Easel at ${RECT}`);
const CANVAS_OPEN = /^\[Forgery\] Canvas open at stroke (\d+) of (\d+)/;
const GHOSTS = /^\[Forgery\] Ghosts in base units (.+)$/;
// A pause between a drag's points, so the engine's input accumulation (one merged drag a
// frame) keeps the stroke's shape.
const DRAG_STEP_MS = 20;
// How many times a tap is repeated after a catch tossed the mime back to the entrance.
const ATTEMPTS = 5;
// "[Room] Frame|Portrait <name> at (x, y)": where a tilt frame or hiding portrait hangs.
const hungLog = (kind, name) => new RegExp(`^\\[Room\\] ${kind} ${name} at \\(([\\d.-]+), ([\\d.-]+)\\)`);
// The hall's corridor guard turns at the far door (its waypoint 1).
const FAR_TURN = /^\[Guard\] Guard reaches waypoint 1 /;
// From the far turn until the hall guard has walked back past the middle portrait.
const PASSED_MIDDLE_MS = 8000;
const CAUGHT = /^\[Room\] Caught/;
// A room change logs its arrival before the fade back in ends, and the fade's cover takes
// every touch until then (Game.FADE_TIME 0.25 s): taps wait this long after an arrival.
const FADE_WAIT_MS = 500;
// Long enough for the gallery guard's whole patrol loop (about 25 s).
const GUARD_WAIT_MS = 40000;

// Waits until a console line logged at or after index `from` matches `pattern` (a RegExp)
// and returns its match (with `index`: the line's index in logs).
async function waitForLog(page, logs, pattern, what, from = 0, timeoutMs = STEP_TIMEOUT_MS) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    for (let i = logs.length - 1; i >= from; i--) {
      const match = logs[i].match(pattern);
      if (match) return Object.assign(match, { index: i });
    }
    await page.waitForTimeout(50);
  }
  throw new Error(`timed out after ${timeoutMs} ms waiting for ${what} (${pattern})`);
}

// Pointer input for one run: real touches (CDP touch events) on a phone, the mouse on desktop.
async function pointerFor(page, context, run) {
  if (!run.context.hasTouch) {
    return {
      tap: (p) => page.mouse.click(p.x, p.y),
      drag: async (points) => {
        await page.mouse.move(points[0].x, points[0].y);
        await page.mouse.down();
        for (const p of points.slice(1)) {
          await page.waitForTimeout(DRAG_STEP_MS);
          await page.mouse.move(p.x, p.y);
        }
        await page.mouse.up();
      },
    };
  }
  const cdp = await context.newCDPSession(page);
  // id 7: iOS Safari gives touches large identifiers, never 0, and Godot web uses them as the index.
  const touch = (type, points) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: points });
  return {
    tap: async (p) => {
      await touch('touchStart', [{ x: p.x, y: p.y, id: 7 }]);
      await touch('touchEnd', []);
    },
    drag: async (points) => {
      await touch('touchStart', [{ x: points[0].x, y: points[0].y, id: 7 }]);
      for (const p of points.slice(1)) {
        await page.waitForTimeout(DRAG_STEP_MS);
        await touch('touchMove', [{ x: p.x, y: p.y, id: 7 }]);
      }
      await touch('touchEnd', []);
    },
  };
}

// The world's offset on screen (base units) from the latest screen fit log.
function worldOffset(logs) {
  const line = logs.findLast((each) => WORLD_AT.test(each));
  const match = line === undefined ? null : line.match(WORLD_AT);
  return match === null ? { x: 0, y: 0 } : { x: Number(match[1]), y: Number(match[2]) };
}

// A base-unit point in page coordinates, shifted by `offset` (a world point: worldOffset).
// Godot fits the 960x540 base by the smaller ratio and expands the other axis from the
// top-left.
async function pagePoint(page, x, y, offset) {
  return (await pagePoints(page, [[x, y]], offset))[0];
}

// pagePoint for a list of [x, y] base-unit points with one canvas lookup (each lookup is
// slow on a busy page: a stroke mapped point by point gives the guard time to come round).
async function pagePoints(page, points, offset) {
  const box = await page.locator('canvas').boundingBox();
  const scale = Math.min(box.width / BASE.width, box.height / BASE.height);
  return points.map(([x, y]) => ({ x: box.x + (x + offset.x) * scale, y: box.y + (y + offset.y) * scale }));
}

// Paints the fake: taps the easel (base units), then drags along every ghost from the one
// the canvas resumes at, until "[Room] Fake ready"; a catch is waited out until the mime
// is back at the entrance, then it paints on.
async function paintFake(page, logs, pointer, easel) {
  for (let attempt = 1; attempt <= ATTEMPTS; attempt++) {
    const from = logs.length;
    await pointer.tap(await pagePoint(page, easel.x, easel.y, worldOffset(logs)));
    const open = await waitForLog(page, logs, new RegExp(`${CANVAS_OPEN.source}|^\\[Room\\] Caught`), 'the canvas at the easel', from);
    if (open[1] !== undefined) {
      const ghosts = JSON.parse((await waitForLog(page, logs, GHOSTS, 'the ghost strokes', open.index))[1]);
      for (let i = Number(open[1]) - 1; i < ghosts.length; i++) {
        if (logs.slice(from).some((line) => line.startsWith('[Room] Caught'))) break;
        await pointer.drag(await pagePoints(page, ghosts[i], worldOffset(logs)));
      }
    }
    const outcome = await waitForLog(page, logs, /^\[Room\] Fake ready|^\[Room\] Caught/, 'the painted fake', from);
    if (outcome[0].startsWith('[Room] Fake ready')) return attempt;
    await waitForLog(page, logs, /^\[Room\] The mime is back at the entrance/, 'the end of the toss', outcome.index);
  }
  throw new Error(`painting: caught on every one of ${ATTEMPTS} attempts`);
}

// Taps `point` (base units) until the room logs `goal` (a RegExp); a catch in between is
// waited out until the mime is back at the entrance, then the tap is repeated. With
// `window` (a RegExp), each tap waits for a fresh log line matching it first.
async function tapUntil(page, logs, pointer, point, goal, what, window = null) {
  for (let attempt = 1; attempt <= ATTEMPTS; attempt++) {
    if (window !== null) await waitForLog(page, logs, window, `the guard's safe window before ${what}`, logs.length, GUARD_WAIT_MS);
    const from = logs.length;
    await pointer.tap(await pagePoint(page, point.x, point.y, worldOffset(logs)));
    const outcome = await waitForLog(page, logs, new RegExp(`${goal.source}|^\\[Room\\] Caught`), what, from);
    if (goal.test(outcome[0])) return attempt;
    await waitForLog(page, logs, /^\[Room\] The mime is back at the entrance/, 'the end of the toss', outcome.index);
  }
  throw new Error(`${what}: caught on every one of ${ATTEMPTS} attempts`);
}

// Runs `steps` (an async function of the log index it starts at) until it ends without a catch;
// a catch ends the try (steps' waits watch for it via `watch`): it is waited out until the mime is
// back at the entrance, then steps run again, at most ATTEMPTS times. Returns the attempt.
async function untilClean(page, logs, what, steps) {
  for (let attempt = 1; attempt <= ATTEMPTS; attempt++) {
    const from = logs.length;
    const watch = async (pattern, label, timeoutMs = STEP_TIMEOUT_MS) => {
      const hit = await waitForLog(page, logs, new RegExp(`${pattern.source}|${CAUGHT.source}`), label, from, timeoutMs);
      if (CAUGHT.test(hit[0])) throw Object.assign(new Error('caught'), { caughtAt: hit.index });
      return hit;
    };
    try {
      await steps(from, watch);
      return attempt;
    } catch (error) {
      if (error.caughtAt === undefined) throw error;
      await waitForLog(page, logs, /^\[Room\] The mime is back at the entrance/, 'the end of the toss', error.caughtAt);
    }
  }
  throw new Error(`${what}: caught on every one of ${ATTEMPTS} attempts`);
}

// The point a hung frame's or portrait's log names, logged at or after `from`.
async function hungAt(page, logs, kind, name, from) {
  const hung = await waitForLog(page, logs, hungLog(kind, name), `${kind} ${name}`, from);
  return { x: Number(hung[1]), y: Number(hung[2]) };
}

// The point a door log (doorLog) names, logged at or after `from`.
async function doorAt(page, logs, to, from) {
  const door = await waitForLog(page, logs, doorLog(to), `the door to room ${to}`, from);
  return { x: Number(door[1]), y: Number(door[2]) };
}

// Wing door `n`'s spot and state in the hub logged at or after `from`.
async function wingDoorAt(page, logs, n, from) {
  const door = await waitForLog(page, logs, wingDoorLog(n), `wing door ${n} in the hub`, from);
  return { x: Number(door[1]), y: Number(door[2]), state: door[3], stars: Number(door[4]) };
}

// Wing 1 end to end: play, wing 1's door in the hub, paint the fake in the foyer, through the hall to the gallery,
// swap the masterpiece, back through the hall to the foyer, escape, the results, home to
// the hub with wing 1's stars on its door and wing 2 open.
async function playWing1(page, logs, pointer, run) {
  const arrived = /^\[Game\] Arrived at ROOM/;
  const play = await waitForLog(page, logs, PLAY_RECT, 'the play button\'s rect');
  const [px, py, pw, ph] = play.slice(1).map(Number);
  let from = logs.length;
  await pointer.tap(await pagePoint(page, px + pw / 2, py + ph / 2, { x: 0, y: 0 }));
  await waitForLog(page, logs, /^\[Game\] Arrived at HUB/, 'the hub after tapping play', from);
  const wing1 = await wingDoorAt(page, logs, 1, from);
  if (wing1.state !== 'open') throw new Error(`wing 1's door is ${wing1.state} on a fresh save`);
  await page.waitForTimeout(FADE_WAIT_MS);
  from = logs.length;
  await pointer.tap(await pagePoint(page, wing1.x, wing1.y + WING_DOOR_TAP_Y, worldOffset(logs)));
  await waitForLog(page, logs, arrived, 'the foyer after wing 1\'s door', from);
  const easel = await waitForLog(page, logs, EASEL_RECT, 'the easel', from);
  const [ax, ay, aw, ah] = easel.slice(1).map(Number);
  const toHall = await doorAt(page, logs, 1, from);
  await page.waitForTimeout(FADE_WAIT_MS);
  const paints = await paintFake(page, logs, pointer, { x: ax + aw / 2, y: ay + ah / 2 });
  const fake = logs.find((line) => line.startsWith('[Room] Fake ready'));
  from = logs.length;
  await tapUntil(page, logs, pointer, toHall, arrived, 'the hall');
  const toGallery = await doorAt(page, logs, 2, from);
  const middle = await hungAt(page, logs, 'Portrait', 'PortraitA', from);
  const far = await hungAt(page, logs, 'Portrait', 'PortraitB', from);
  await page.waitForTimeout(FADE_WAIT_MS);
  // The hall: into the middle portrait behind the guard; out once he has turned and passed it.
  await untilClean(page, logs, 'the hall', async (start, watch) => {
    await pointer.tap(await pagePoint(page, middle.x, middle.y, worldOffset(logs)));
    await watch(/^\[Room\] Hid in the portrait/, 'hiding in the hall');
    await watch(FAR_TURN, 'the hall guard\'s far turn', GUARD_WAIT_MS);
    await page.waitForTimeout(PASSED_MIDDLE_MS);
    await pointer.tap(await pagePoint(page, toGallery.x, toGallery.y, worldOffset(logs)));
    await watch(arrived, 'the gallery');
  });
  from = logs.findLastIndex((line) => arrived.test(line));
  const masterpiece = await waitForLog(page, logs, MASTERPIECE_RECT, 'the masterpiece', from);
  const [rx, ry, rw, rh] = masterpiece.slice(1).map(Number);
  const backToHall = await doorAt(page, logs, 1, from);
  const lure = await hungAt(page, logs, 'Frame', 'FrameA', from);
  await page.waitForTimeout(FADE_WAIT_MS);
  // The gallery: low round the right, tilt the far frame, step aside as the sentry comes, swap.
  const swaps = await untilClean(page, logs, 'the swap', async (start, watch) => {
    await pointer.tap(await pagePoint(page, lure.x - 80, 380, worldOffset(logs)));
    await watch(/^\[Mime\] Arrived/, 'below the far frame');
    await pointer.tap(await pagePoint(page, lure.x, lure.y, worldOffset(logs)));
    await watch(/^\[Room\] Tilted the frame/, 'the tilt');
    await pointer.tap(await pagePoint(page, lure.x + 20, 360, worldOffset(logs)));
    await watch(/^\[Guard\] Guard now STRAIGHTEN/, 'the sentry at the frame');
    await pointer.tap(await pagePoint(page, rx + rw / 2, ry + rh / 2, worldOffset(logs)));
    await watch(/^\[Room\] Swapped/, 'the swap');
  });
  from = logs.length;
  await tapUntil(page, logs, pointer, backToHall, arrived, 'the hall again');
  const toFoyer = await doorAt(page, logs, 0, from);
  await page.waitForTimeout(FADE_WAIT_MS);
  // Back through the hall: into the far portrait at once; out once the guard turns past it.
  await untilClean(page, logs, 'the hall again', async (start, watch) => {
    await pointer.tap(await pagePoint(page, far.x, far.y, worldOffset(logs)));
    await watch(/^\[Room\] Hid in the portrait/, 'hiding in the hall again');
    await watch(FAR_TURN, 'the hall guard\'s far turn again', GUARD_WAIT_MS);
    await pointer.tap(await pagePoint(page, toFoyer.x, toFoyer.y, worldOffset(logs)));
    await watch(arrived, 'the foyer again');
  });
  from = logs.findLastIndex((line) => arrived.test(line));
  const exit = await doorAt(page, logs, -1, from);
  await page.waitForTimeout(FADE_WAIT_MS);
  const exits = await tapUntil(page, logs, pointer, exit, /^\[Room\] Escaped/, 'the escape');
  const stars = await waitForLog(page, logs, /^\[Results\] Stars/, 'the results');
  const home = await waitForLog(page, logs, /^\[Results\] Home button at \(([\d.-]+), ([\d.-]+)\)/, 'the home button');
  // The stars pop in one after another; the buttons work at once, but wait for the screenshot.
  await page.waitForTimeout(1500);
  await page.screenshot({ path: join(buildDir, '..', `smoke-${run.name}-results.png`) });
  from = logs.length;
  await pointer.tap(await pagePoint(page, Number(home[1]), Number(home[2]), { x: 0, y: 0 }));
  await waitForLog(page, logs, /^\[Game\] Arrived at HUB/, 'the hub after home', from);
  const after = await wingDoorAt(page, logs, 1, from);
  const wing2 = await wingDoorAt(page, logs, 2, from);
  if (after.stars < 1 || wing2.state !== 'open') throw new Error(`back in the hub wing 1 shows ${after.stars} star(s) and wing 2 is ${wing2.state}`);
  console.log(`[${run.name}] wing 1: painted on attempt ${paints} (${fake}), swap on attempt ${swaps}, escape on attempt ${exits}; ${stars.input}; hub: wing 1 ${after.stars} star(s), wing 2 ${wing2.state}`);
}

async function smoke(browser, url, run) {
  const failures = [];
  const logs = [];
  const context = await browser.newContext(run.context);
  try {
    const page = await context.newPage();
    page.on('pageerror', (e) => failures.push(`page error: ${e.message}`));
    page.on('requestfailed', (r) => failures.push(`request failed: ${r.url()} ${r.failure()?.errorText}`));
    page.on('response', (r) => { if (r.status() >= 400) failures.push(`HTTP ${r.status()}: ${r.url()}`); });
    page.on('console', (m) => {
      // SwiftShader emits GPU performance warnings; only real errors fail the test.
      if (m.type() === 'error') failures.push(`console error: ${m.text()}`);
      logs.push(m.text());
    });
    // Settled to a value up front so it can never become an unhandled rejection if goto throws.
    const booted = page.waitForEvent('console', {
      predicate: (m) => m.text().startsWith('Godot Engine v'),
      timeout: bootTimeoutMs,
    }).then(() => null, (err) => err);
    await page.goto(url, { timeout: bootTimeoutMs });
    const bootError = await booted;
    if (bootError !== null) throw new Error(`engine did not boot: ${bootError.message.split('\n')[0]}`);
    await waitForLog(page, logs, /^\[Game\] Arrived at TITLE/, 'the title (the main scene)');
    await page.waitForTimeout(settleMs);
    const overlayVisible = await page.evaluate(() => {
      const status = document.getElementById('status');
      return status !== null && getComputedStyle(status).display !== 'none' && getComputedStyle(status).visibility !== 'hidden';
    });
    if (overlayVisible) failures.push('Godot status overlay still visible (engine failed to start)');
    if ((await page.locator('canvas').count()) === 0) failures.push('no canvas element');
    const css = await page.evaluate((expected) => {
      const wrong = [];
      for (const selector of ['html', 'body', 'canvas']) {
        const style = getComputedStyle(document.querySelector(selector));
        for (const [prop, value] of Object.entries(expected)) {
          if (style[prop] !== value) wrong.push(`${selector} ${prop}=${style[prop]}`);
        }
      }
      return wrong;
    }, TOUCH_CSS);
    for (const w of css) failures.push(`touch CSS not applied: ${w}`);
    const screenshotPath = join(buildDir, '..', `smoke-${run.name}.png`);
    const png = await page.screenshot({ path: screenshotPath });
    console.log(`[${run.name}] screenshot: ${screenshotPath}`);
    // A booted engine that draws nothing leaves one flat colour; count distinct colours in the screenshot.
    const distinctColors = await page.evaluate(async (b64) => {
      const img = new Image();
      img.src = `data:image/png;base64,${b64}`;
      await img.decode();
      const canvas = document.createElement('canvas');
      canvas.width = img.width;
      canvas.height = img.height;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0);
      const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
      const colors = new Set();
      for (let i = 0; i < data.length && colors.size < 16; i += 4) {
        colors.add((data[i] << 16) | (data[i + 1] << 8) | data[i + 2]);
      }
      return colors.size;
    }, png.toString('base64'));
    if (distinctColors < 2) failures.push('screenshot is a single flat colour (nothing rendered)');
    if (failures.length === 0) {
      await playWing1(page, logs, await pointerFor(page, context, run), run);
      await page.waitForTimeout(settleMs);
      const hubPath = join(buildDir, '..', `smoke-${run.name}-hub.png`);
      await page.screenshot({ path: hubPath });
      console.log(`[${run.name}] screenshots: ${join(buildDir, '..', `smoke-${run.name}-results.png`)}, ${hubPath}`);
      // The wing's loop and the swap's sound played in the export (a load failure is a console
      // error), and the ghost mime found its replay (a JSON file the export must include).
      for (const want of ['[Audio] Music wing_01', '[Audio] SFX swap', '[Room] Ghost mime replays']) {
        if (!logs.some((line) => line.startsWith(want))) failures.push(`the web run never logged "${want}"`);
      }
    }
    for (const line of logs.filter((l) => /^\[(Game|Room|Results|Hub)\]|^\[Audio\] (Music|Voice)/.test(l))) console.log(`[${run.name}] ${line}`);
  } catch (err) {
    failures.push(`smoke test aborted: ${err.message}`);
    // The game's last log lines show where the run got stuck.
    for (const line of logs.slice(-12)) failures.push(`  log: ${line}`);
  } finally {
    await context.close();
  }
  return failures.map((f) => `[${run.name}] ${f}`);
}

const failures = [];
let browser;
let server;
try {
  const served = await serveBuild(buildDir);
  server = served.server;
  browser = await launchChrome();
  for (const run of RUNS) failures.push(...await smoke(browser, served.url, run));
} catch (err) {
  failures.push(`smoke test aborted: ${err.message}`);
} finally {
  await browser?.close();
  server?.close();
}

if (failures.length > 0) {
  for (const f of failures) console.error(`FAIL ${f}`);
  process.exit(1);
}
console.log(`PASS ${buildDir} (${RUNS.map((r) => r.name).join(', ')})`);
