// Run real Chromium checks of the drop-down menus and dialogs of ui-lib.js.
// Usage: node t/ui-menu-dialog-browser.mjs [artifact-directory]
import assert from 'node:assert/strict';
import { spawn, execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const dir = process.argv[2] || mkdtempSync(join(tmpdir(), 'ui-menu-dialog-browser-'));
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const html = join(dir, 'menus.html');
writeFileSync(html, execFileSync('perl', [join(root, 't/ui-menu-dialog-fixture.pl')]));
const binary = process.env.CHROMIUM_BINARY || (process.platform === 'darwin'
    ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' : 'chromium');
const chrome = spawn(binary, ['--headless', '--remote-debugging-pipe', '--no-first-run',
    '--no-default-browser-check', '--disable-background-networking', '--disable-extensions',
    '--disable-sync', `--user-data-dir=${join(dir, 'browser-test-profile')}`, 'about:blank'],
    { stdio: ['ignore', 'ignore', 'ignore', 'pipe', 'pipe'] });
let nextId = 0, buffer = '';
const pending = new Map();
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
    await page('Emulation.setDeviceMetricsOverride', { width: 1000, height: 700, deviceScaleFactor: 1, mobile: false });
    await page('Page.navigate', { url: pathToFileURL(html).href });
    for (let n = 0; n < 100; n++) {
        if (await evaluate("document.readyState === 'complete' && !!window.webminUiWidgets && !!window.webminUiWidgets.openDialog")) break;
        await new Promise(r => setTimeout(r, 50));
    }
    await evaluate(`window.q = s => document.querySelector(s);
        window.key = (s, key) => q(s).dispatchEvent(new KeyboardEvent('keydown', {bubbles:true, cancelable:true, key}));
        window.tick = () => new Promise(r => setTimeout(r, 20));`);

    // One menu open at a time, closed by a click elsewhere
    assert.equal(await evaluate("q('#menu_file').open"), false);
    await evaluate("q('#menu_file > summary').click()");
    assert.equal(await evaluate("q('#menu_file').open"), true);
    await evaluate("q('#menu_more > summary').click()");
    assert.equal(await evaluate("q('#menu_file').open"), false, 'opening another menu closes the first');
    assert.equal(await evaluate("q('#menu_more').open"), true);
    await evaluate("document.body.click()");
    assert.equal(await evaluate("q('#menu_more').open"), false, 'a click elsewhere closes the menu');

    // A menu at the right edge flips so it stays in the window
    await evaluate("q('#menu_edge > summary').click(); tick()");
    assert.equal(await evaluate("q('#menu_edge').classList.contains('ui_dropdown_flip')"), true, 'edge menu is flipped');
    assert.ok(await evaluate("q('#menu_edge .ui_dropdown_menu').getBoundingClientRect().right <= innerWidth"), 'flipped menu stays inside the window');
    await evaluate("document.body.click()");
    assert.equal(await evaluate("q('#menu_edge').classList.contains('ui_dropdown_flip')"), false, 'flip is cleared on close');

    // Keyboard : arrows open the menu and move between entries, skipping
    // disabled ones; Escape closes it and returns to the button
    await evaluate("q('#menu_file > summary').focus(); key('#menu_file > summary', 'ArrowDown')");
    assert.equal(await evaluate("q('#menu_file').open"), true, 'ArrowDown opens the menu');
    assert.equal(await evaluate("document.activeElement.id"), 'item_new', 'ArrowDown focuses the first entry');
    await evaluate("key('#item_new', 'ArrowDown')");
    assert.equal(await evaluate("document.activeElement.id"), 'item_open');
    await evaluate("key('#item_open', 'End')");
    assert.equal(await evaluate("document.activeElement.id"), 'item_delete', 'End skips the disabled last entry');
    await evaluate("key('#item_delete', 'ArrowDown')");
    assert.equal(await evaluate("document.activeElement.id"), 'item_new', 'arrows wrap around');
    await evaluate("key('#item_new', 'Escape')");
    assert.equal(await evaluate("q('#menu_file').open"), false, 'Escape closes the menu');
    assert.equal(await evaluate("document.activeElement === q('#menu_file > summary')"), true, 'Escape returns focus to the button');

    // A menu entry opens its dialog and the menu closes
    await evaluate("q('#menu_file > summary').click(); q('#item_new').click(); tick()");
    assert.equal(await evaluate("q('#dlg_rename').open"), true, 'entry opens its dialog');
    assert.equal(await evaluate("q('#menu_file').open"), false, 'menu closes after the entry');
    await evaluate("q('#dlg_rename .ui_dialog_x').click()");
    assert.equal(await evaluate("q('#dlg_rename').open"), false, 'the cross closes the dialog');

    // A dialog button fills the fields it carries, and the Cancel button closes
    await evaluate("q('#open_rename').click()");
    assert.equal(await evaluate("q('#dlg_rename').open"), true);
    assert.equal(await evaluate("q('#dlg_rename [name=name]').value"), 'web01.conf', 'text field filled');
    assert.equal(await evaluate("q('#dlg_rename [name=file]').value"), 'web01.conf', 'hidden field filled');
    assert.equal(await evaluate("q('#dlg_rename [name=keep]').checked"), true, 'checkbox checked from a value');
    assert.equal(await evaluate("document.activeElement === q('#dlg_rename [name=name]')"), true, 'first field takes the focus');
    await evaluate("q('#dlg_rename .ui_dialog_foot [data-ui-dialog-close]').click()");
    assert.equal(await evaluate("q('#dlg_rename').open"), false, 'Cancel closes the dialog');

    // A click on the backdrop closes the dialog; one inside does not
    await evaluate("q('#open_rename').click()");
    await evaluate("q('#dlg_rename .ui_dialog_body').dispatchEvent(new MouseEvent('click', {bubbles:true, clientX:innerWidth/2, clientY:innerHeight/2}))");
    assert.equal(await evaluate("q('#dlg_rename').open"), true, 'a click inside keeps the dialog');
    await evaluate("q('#dlg_rename').dispatchEvent(new MouseEvent('click', {bubbles:true, clientX:2, clientY:2}))");
    assert.equal(await evaluate("q('#dlg_rename').open"), false, 'a click on the backdrop closes the dialog');

    // The confirmation : Cancel takes the focus, and the dialog-method form
    // closes it on submit
    await evaluate("q('#menu_more > summary').click(); q('#menu_more #item_delete').click(); tick()");
    assert.equal(await evaluate("q('#dlg_confirm').open"), true);
    assert.equal(await evaluate("document.activeElement.id"), 'confirm_cancel', 'autofocus lands on Cancel');
    await evaluate("q('#confirm_go').click(); tick()");
    assert.equal(await evaluate("q('#dlg_confirm').open"), false, 'submitting a dialog-method form closes it');

    // The script API, and a module listener refusing an opening
    await evaluate("webminUiWidgets.openDialog('dlg_rename', {name: 'other'})");
    assert.equal(await evaluate("q('#dlg_rename').open && q('#dlg_rename [name=name]').value"), 'other', 'openDialog fills and opens');
    await evaluate("webminUiWidgets.closeDialog('dlg_rename')");
    assert.equal(await evaluate("q('#dlg_rename').open"), false, 'closeDialog closes');
    await evaluate("document.addEventListener('ui-dialog-open', e => { if (window.veto) e.preventDefault(); }); window.veto = true");
    assert.equal(await evaluate("webminUiWidgets.openDialog('dlg_rename')"), null, 'a refused opening returns null');
    assert.equal(await evaluate("q('#dlg_rename').open"), false, 'and the dialog stays closed');
    await evaluate("window.veto = false");

    // Confirmations : the question is asked in a dialog, Cancel keeps the
    // action from running and OK replays it, for a submit button and a link
    await evaluate("q('#confirm_submit').click(); tick()");
    assert.equal(await evaluate("q('#ui_confirm').open"), true, 'confirm dialog opens');
    assert.equal(await evaluate("q('#ui_confirm [data-ui-confirm-text]').textContent"), 'Really delete?', 'question shown');
    assert.equal(await evaluate("q('#ui_confirm').classList.contains('ui_dialog_danger')"), true, 'state from the control');
    assert.equal(await evaluate("q('#ui_confirm [data-ui-confirm-ok] .ui_action_content > span').textContent"), 'Delete', 'label from the control');
    assert.equal(await evaluate("document.activeElement.hasAttribute('data-ui-dialog-close')"), true, 'Cancel has the focus');
    await evaluate("q('#ui_confirm .ui_dialog_foot [data-ui-dialog-close]').click(); tick()");
    assert.equal(await evaluate("q('#ui_confirm').open"), false, 'Cancel closes the question');
    assert.equal(await evaluate("window.submitted || 0"), 0, 'Cancel keeps the form from submitting');
    await evaluate("q('#confirm_submit').click(); tick()");
    await evaluate("q('#ui_confirm [data-ui-confirm-ok]').click(); tick()");
    assert.equal(await evaluate("window.submitted"), 1, 'OK submits the form');
    assert.equal(await evaluate("q('#ui_confirm').open"), false, 'and closes the question');
    await evaluate("q('#confirm_link').click(); tick()");
    assert.equal(await evaluate("location.hash"), '', 'a link waits for the answer');
    assert.equal(await evaluate("q('#ui_confirm').classList.contains('ui_dialog_warning')"), true, 'warning state by default');
    await evaluate("q('#ui_confirm [data-ui-confirm-ok]').click(); tick()");
    assert.equal(await evaluate("location.hash"), '#confirmed', 'OK follows the link');
    const answer = await evaluate("new Promise(r => { webminUiWidgets.confirm('Sure?', { title: 'Ask', ok: 'Yes' }).then(r); setTimeout(() => q('#ui_confirm [data-ui-confirm-ok]').click(), 20); })");
    assert.equal(answer, true, 'the script API resolves with the answer');
    assert.equal(await evaluate("q('#ui_confirm_title').textContent"), 'Ask', 'title from the options');

    // Breadcrumbs and pager render their current items
    assert.equal(await evaluate("q('.ui_breadcrumb_current').getAttribute('aria-current')"), 'page');
    assert.equal(await evaluate("q('.ui_pager_current').textContent"), '3');
    assert.equal(await evaluate("document.querySelectorAll('.ui_pager a').length"), 7, 'prev, 1, 2, 4, 5, 9 and next are links');

    // Both schemes render without horizontal overflow
    for (const scheme of ['light', 'dark']) {
        await evaluate(`q('#page').dataset.uiScheme = '${scheme}'; q('#menu_file > summary').click()`);
        assert.equal(await evaluate("document.documentElement.scrollWidth <= innerWidth"), true, `no horizontal overflow in ${scheme}`);
        const shot = await page('Page.captureScreenshot', { format: 'png' });
        writeFileSync(join(dir, scheme + '.png'), Buffer.from(shot.data, 'base64'));
        await evaluate("document.body.click()");
    }
    console.log('PASS: menus (single open, outside click, flip, keyboard), dialogs (entry, button values, cross, cancel, backdrop, confirm, API, veto), breadcrumbs and pager');
} finally {
    clearTimeout(timeout);
    await command('Browser.close').catch(() => {});
    chrome.kill();
}
