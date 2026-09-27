// Run real Chromium selection checks without third-party browser dependencies.
// Usage: node t/ui-multi-select-browser.mjs [artifact-directory] [cloudmin-checkout]
import assert from 'node:assert/strict';
import { spawn, execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const dir = process.argv[2] || mkdtempSync(join(tmpdir(), 'ui-multi-browser-'));
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const html = join(dir, 'selector.html');
writeFileSync(html, execFileSync('perl', [join(root, 't/ui-multi-select-fixture.pl'), ...process.argv.slice(3)]));
const binary = process.env.CHROMIUM_BINARY || (process.platform === 'darwin'
    ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' : 'chromium');
const chrome = spawn(binary, ['--headless', '--remote-debugging-pipe', '--no-first-run',
    '--no-default-browser-check', '--disable-background-networking', '--disable-extensions',
    '--disable-sync', `--user-data-dir=${join(dir, 'browser-test-profile')}`, 'about:blank'],
    { stdio: ['ignore', 'ignore', 'ignore', 'pipe', 'pipe'] });
let nextId = 0, buffer = '';
const pending = new Map();
// Fail outstanding calls when Chromium cannot start or exits unexpectedly.
const rejectPending = error => {
    for (const request of pending.values()) request.reject(error);
    pending.clear();
};
chrome.on('error', rejectPending);
chrome.on('exit', code => rejectPending(new Error(`Chromium exited (${code})`)));
chrome.stdio[4].on('data', chunk => {
    buffer += chunk;
    let end;
    while ((end = buffer.indexOf('\0')) >= 0) {
        const message = JSON.parse(buffer.slice(0, end));
        buffer = buffer.slice(end + 1);
        const promise = pending.get(message.id);
        if (promise) {
            pending.delete(message.id);
            message.error ? promise.reject(new Error(JSON.stringify(message.error))) : promise.resolve(message.result);
        }
    }
});

// command(method, params, sessionId) sends one DevTools request over private pipes.
function command(method, params = {}, sessionId) {
    if (chrome.exitCode !== null || chrome.signalCode !== null) return Promise.reject(new Error('Chromium is closed'));
    const id = ++nextId;
    return new Promise((resolve, reject) => {
        pending.set(id, { resolve, reject });
        chrome.stdio[3].write(JSON.stringify({ id, method, params, sessionId }) + '\0');
    });
}
const timeout = setTimeout(() => { console.error('Browser checks timed out'); chrome.kill(); process.exitCode = 1; }, 45000);
try {
    const { targetId } = await command('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await command('Target.attachToTarget', { targetId, flatten: true });
    const page = (method, params) => command(method, params, sessionId);
    const evaluate = async expression => {
        const result = await page('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
        if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
        return result.result.value;
    };
    await page('Emulation.setDeviceMetricsOverride', { width: 1120, height: 900, deviceScaleFactor: 1, mobile: false });
    await page('Page.navigate', { url: pathToFileURL(html).href });
    for (let n = 0; n < 100; n++) {
        if (await evaluate("document.readyState === 'complete' && !!document.querySelector('#ui_multi_grouped')")) break;
        await new Promise(r => setTimeout(r, 50));
    }
    await evaluate(`window.box = id => document.querySelector('#ui_multi_' + id);
        window.value = id => box(id).querySelector('input[type=hidden][name="' + id + '"]').value;
        window.search = text => { const input = box('grouped').querySelector('[data-ui-multi-search]'); input.value = text; input.dispatchEvent(new Event('input', {bubbles:true})); };
        window.visible = selector => [...box('grouped').querySelectorAll(selector)].filter(e => !e.hidden).length;`);

    // Filtering retains selections and removes empty headings; bulk actions stay scoped.
    assert.equal(await evaluate("value('grouped')"), 'image-0');
    await evaluate("search('Older')");
    assert.equal(await evaluate("visible('[data-ui-multi-heading]')"), 1);
    assert.equal(await evaluate("visible('.ui_multi_item')"), 2);
    await evaluate("box('grouped').querySelector('[data-ui-multi-action=all]').click()");
    assert.equal(await evaluate("value('grouped')"), 'image-0\nimage-8');
    await evaluate("box('grouped').querySelector('[data-ui-multi-action=invert]').click()");
    assert.equal(await evaluate("value('grouped')"), 'image-0');
    await evaluate("search('Minimum disk size')");
    assert.equal(await evaluate("visible('.ui_multi_item')"), 10);
    await evaluate("search('not present')");
    assert.equal(await evaluate("visible('[data-ui-multi-heading]')"), 0);
    assert.equal(await evaluate("box('grouped').querySelector('.ui_multi_empty').hidden"), false);
    await evaluate("search('')");

    // Shift-click crosses headings while excluding disabled choices.
    await evaluate(`const first = box('grouped').querySelector('input[value="image-1"]'); first.click();
        box('grouped').querySelector('input[value="image-5"]').dispatchEvent(new MouseEvent('click', {bubbles:true, shiftKey:true}));`);
    assert.equal(await evaluate("value('grouped')"), 'image-0\nimage-1\nimage-2\nimage-3\nimage-4\nimage-5');

    // Virtualmin hierarchy, selected child retention, modes and tags remain unchanged.
    assert.equal(await evaluate("value('domains')"), 'parent\nchild');
    assert.equal(await evaluate("box('domains').querySelector('[data-ui-multi-level]').hidden"), true);
    assert.equal(await evaluate("box('domains').querySelector('.ui_multi_count').textContent"), '1 selected');
    assert.equal(await evaluate("box('domains').querySelector('.ui_chip').textContent"), 'Disabled');
    await evaluate("box('domains').querySelector('[data-ui-multi-action=children]').click()");
    assert.equal(await evaluate("box('domains').querySelector('[data-ui-multi-level]').hidden"), false);
    await evaluate(`const mode = box('domains').querySelector('select'); mode.value = '1'; mode.dispatchEvent(new Event('change', {bubbles:true}));`);
    assert.equal(await evaluate("box('domains').querySelector('.ui_multi_body').hidden"), true);
    assert.equal(await evaluate("value('domains')"), 'parent\nchild');
    assert.equal(await evaluate("box('domains').classList.contains('ui_multi_compact')"), false);

    // Decoration must not flatten hierarchy or change literal tooltip text.
    for (const compact of [0, 1]) {
        const id = 'nested' + compact;
        assert.equal(await evaluate(`box('${id}').querySelector('[data-ui-multi-heading="2"]').hidden`), true);
        await evaluate(`box('${id}').querySelector('[data-ui-multi-action=children]').click()`);
        assert.equal(await evaluate(`box('${id}').querySelector('[data-ui-multi-heading="2"]').hidden`), false);
        assert.deepEqual(await evaluate(`[...box('${id}').querySelectorAll('[data-ui-multi-level]')].map(row => parseFloat(getComputedStyle(row).paddingLeft))`), [27, 47]);
        assert.equal(await evaluate(`box('${id}').querySelector('.ui_multi_meta').title`), 'Literal &amp; <tip> "quoted"');
    }

    // Legacy order and selected labels survive changes and a native form reset.
    assert.equal(await evaluate("value('legacy')"), 'b\na');
    await evaluate("box('legacy').querySelector('input[value=c]').click()");
    assert.equal(await evaluate("value('legacy')"), 'c\nb\na');
    assert.match(await evaluate("box('legacy').textContent"), /Chosen B/);
    await evaluate("document.querySelector('#checks').reset(); new Promise(r => setTimeout(r, 30))");
    assert.equal(await evaluate("value('legacy')"), 'b\na');
    assert.equal(await evaluate("value('grouped')"), 'image-0');
    assert.equal(await evaluate("box('domains').querySelector('[data-ui-multi-level]').hidden"), true);

    // Inspect real Cloudmin metadata in both schemes and a narrow viewport.
    if (process.argv[3]) {
        await evaluate("document.querySelector('#checks').hidden = true");
        assert.equal(await evaluate("[...box('images').querySelectorAll('.ui_multi_item')].every(row => row.querySelectorAll('.ui_badge').length <= 1)"), true);
        assert.doesNotMatch(await evaluate("box('images').textContent"), /ARM64|Min\. disk:|GiB/);
        assert.equal(await evaluate("box('images').querySelector('[data-ui-multi-action=all], [data-ui-multi-action=invert]')"), null);
        await evaluate("box('images').querySelector('input[data-ui-multi-item]').click()");
        assert.equal(await evaluate("value('images').split('\\n').length"), 1);
        assert.equal(await evaluate("box('images').querySelector('.ui_multi_count')"), null);
        for (const scheme of ['light', 'dark']) {
            await evaluate(`document.body.className = 'ui_page'; document.body.dataset.uiScheme = '${scheme}'; document.querySelector('#cloudmin').dataset.uiScheme = '${scheme}'`);
            const shot = await page('Page.captureScreenshot', { format: 'png' });
            writeFileSync(join(dir, scheme + '.png'), Buffer.from(shot.data, 'base64'));
        }
        const height = await evaluate("box('images').querySelector('.ui_multi_item').getBoundingClientRect().height");
        assert.ok(height <= 30, `compact row height is ${height}px`);
        await page('Emulation.setDeviceMetricsOverride', { width: 375, height: 900, deviceScaleFactor: 1, mobile: false });
        assert.equal(await evaluate("document.documentElement.scrollWidth <= innerWidth"), true, 'no narrow-screen horizontal overflow');
        const shot = await page('Page.captureScreenshot', { format: 'png' });
        writeFileSync(join(dir, 'narrow.png'), Buffer.from(shot.data, 'base64'));
    }
    console.log('PASS: grouped selection, filtering, bulk actions, shift-click, Virtualmin hierarchy, modes, legacy order and reset');
} finally {
    clearTimeout(timeout);
    await command('Browser.close').catch(() => {});
    chrome.kill();
}
