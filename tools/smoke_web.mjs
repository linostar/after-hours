// Smoke test for the Godot web export: serves the build locally and loads it in
// headless Chrome twice: as a desktop browser (1280x720) and as a phone held in landscape
// (844x390 at 3x, touch, mobile). Each run fails on any failed request, HTTP error, page
// error, console error, missing engine boot log, the title not arriving ("[Game] Arrived
// at TITLE"), a still-visible Godot status overlay, a missing canvas, a page whose
// touch/selection CSS is not applied, or a screenshot with nothing drawn. Then it plays the
// slice with the mouse (desktop) or CDP touches with id 7 (phone; iOS Safari's touch ids are
// never 0): tap the title's play button where it logs itself ("[Title] Play button at ..."),
// require "[Game] Arrived at ROOM", then play like a player who watches the guard: paint
// the fake first (wait until the guard reaches the bottom-left corner, "[Guard] Guard
// reaches waypoint 3", from where it walks away from the easel; tap the easel where the
// room logs it ("[Room] Easel at ..."), then drag along every ghost stroke the canvas logs
// ("[Forgery] Ghosts in base units ...") from the stroke it resumes at until "[Room] Fake
// ready"; a catch is waited out and the painting resumed), then wait
// until the guard reaches the room's bottom-right corner ("[Guard] Guard reaches waypoint 2", from
// where it walks the bottom leg facing away from the painting), tap the masterpiece where
// the room logs it ("[Room] Masterpiece at ..., exit at ...") until "[Room] Swapped" (a
// catch, "[Room] Caught", is
// waited out until the mime is back at the entrance, then the tap is repeated, at most
// ATTEMPTS times), then tap the exit the same way until "[Room] Escaped", and require
// "[Results] Stars".
// Usage: node tools/smoke_web.mjs [buildDir]   (default: build/web)
// Env:   SMOKE_BOOT_TIMEOUT_MS (default 30000), SMOKE_SETTLE_MS (default 2000),
//        SMOKE_STEP_TIMEOUT_MS (each waited-for log line, default 20000)
// Screenshots (next to buildDir): build/smoke-<run>.png (the title) and
// build/smoke-<run>-results.png (the results overlay).
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
const ROOM_LAYOUT = new RegExp(`^\\[Room\\] Masterpiece at ${RECT}, exit at \\(([\\d.-]+), ([\\d.-]+)\\)`);
const EASEL_RECT = new RegExp(`^\\[Room\\] Easel at ${RECT}`);
const CANVAS_OPEN = /^\[Forgery\] Canvas open at stroke (\d+) of (\d+)/;
const GHOSTS = /^\[Forgery\] Ghosts in base units (.+)$/;
// A pause between a drag's points, so the engine's input accumulation (one merged drag a
// frame) keeps the stroke's shape.
const DRAG_STEP_MS = 20;
// How many times a tap is repeated after a catch tossed the mime back to the entrance.
const ATTEMPTS = 5;
// The guard at the slice room's bottom-right corner: it then walks the bottom leg facing
// away from the painting, the window a watching player takes.
const GUARD_SAFE = /^\[Guard\] Guard reaches waypoint 2 /;
// The guard at the bottom-left corner: it then walks up and along the top, away from the
// easel, for most of its loop.
const GUARD_PAINT_SAFE = /^\[Guard\] Guard reaches waypoint 3 /;
// Long enough for the guard's whole patrol loop (about 19 s).
const GUARD_WAIT_MS = 30000;

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

// A base-unit point in page coordinates. Godot fits the 960x540 base by the smaller ratio
// and expands the other axis from the top-left; the web reports no safe-area insets.
async function pagePoint(page, x, y) {
  return (await pagePoints(page, [[x, y]]))[0];
}

// pagePoint for a list of [x, y] base-unit points with one canvas lookup (each lookup is
// slow on a busy page: a stroke mapped point by point gives the guard time to come round).
async function pagePoints(page, points) {
  const box = await page.locator('canvas').boundingBox();
  const scale = Math.min(box.width / BASE.width, box.height / BASE.height);
  return points.map(([x, y]) => ({ x: box.x + x * scale, y: box.y + y * scale }));
}

// Paints the fake: in the guard's safe window, taps the easel (base units), then drags
// along every ghost from the one the canvas resumes at, until "[Room] Fake ready"; a
// catch is waited out until the mime is back at the entrance, then it paints on.
async function paintFake(page, logs, pointer, easel) {
  for (let attempt = 1; attempt <= ATTEMPTS; attempt++) {
    await waitForLog(page, logs, GUARD_PAINT_SAFE, 'the guard\'s safe window before painting', logs.length, GUARD_WAIT_MS);
    const from = logs.length;
    await pointer.tap(await pagePoint(page, easel.x, easel.y));
    const open = await waitForLog(page, logs, new RegExp(`${CANVAS_OPEN.source}|^\\[Room\\] Caught`), 'the canvas at the easel', from);
    if (open[1] !== undefined) {
      const ghosts = JSON.parse((await waitForLog(page, logs, GHOSTS, 'the ghost strokes', open.index))[1]);
      for (let i = Number(open[1]) - 1; i < ghosts.length; i++) {
        if (logs.slice(from).some((line) => line.startsWith('[Room] Caught'))) break;
        await pointer.drag(await pagePoints(page, ghosts[i]));
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
    await pointer.tap(await pagePoint(page, point.x, point.y));
    const outcome = await waitForLog(page, logs, new RegExp(`${goal.source}|^\\[Room\\] Caught`), what, from);
    if (goal.test(outcome[0])) return attempt;
    await waitForLog(page, logs, /^\[Room\] The mime is back at the entrance/, 'the end of the toss', outcome.index);
  }
  throw new Error(`${what}: caught on every one of ${ATTEMPTS} attempts`);
}

// The slice end to end: play, paint the fake, swap the masterpiece, escape, the results.
async function playSlice(page, logs, pointer, run) {
  const play = await waitForLog(page, logs, PLAY_RECT, 'the play button\'s rect');
  const [px, py, pw, ph] = play.slice(1).map(Number);
  const from = logs.length;
  await pointer.tap(await pagePoint(page, px + pw / 2, py + ph / 2));
  await waitForLog(page, logs, /^\[Game\] Arrived at ROOM/, 'the room after tapping play', from);
  const layout = await waitForLog(page, logs, ROOM_LAYOUT, 'the room layout', from);
  const [rx, ry, rw, rh, ex, ey] = layout.slice(1).map(Number);
  const easel = await waitForLog(page, logs, EASEL_RECT, 'the easel', from);
  const [ax, ay, aw, ah] = easel.slice(1).map(Number);
  const paints = await paintFake(page, logs, pointer, { x: ax + aw / 2, y: ay + ah / 2 });
  const fake = logs.find((line) => line.startsWith('[Room] Fake ready'));
  const swaps = await tapUntil(page, logs, pointer, { x: rx + rw / 2, y: ry + rh / 2 }, /^\[Room\] Swapped/, 'the swap', GUARD_SAFE);
  const exits = await tapUntil(page, logs, pointer, { x: ex, y: ey }, /^\[Room\] Escaped/, 'the escape');
  const stars = await waitForLog(page, logs, /^\[Results\] Stars/, 'the results');
  console.log(`[${run.name}] slice: painted on attempt ${paints} (${fake}), swap on attempt ${swaps}, escape on attempt ${exits}; ${stars.input}`);
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
      await playSlice(page, logs, await pointerFor(page, context, run), run);
      await page.waitForTimeout(settleMs);
      const resultsPath = join(buildDir, '..', `smoke-${run.name}-results.png`);
      await page.screenshot({ path: resultsPath });
      console.log(`[${run.name}] screenshot: ${resultsPath}`);
    }
    for (const line of logs.filter((l) => /^\[(Game|Room|Results)\]/.test(l))) console.log(`[${run.name}] ${line}`);
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
