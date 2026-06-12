// usage: node cdp-clear-and-relogin.mjs <pageId> [quickLoginText] [screenshotDir]
// force fresh login：清 localhost:31079 origin storage + navigate /login + quick-login + verify。
// pageId 必須完整 32 字元（rev2 000 文件 §5.6）。
// 來源：rev2 docs/superpowers/000-base-web-docker-bootstrap.md Appendix A.3（rev2 已實測），rev3 改 port 31079。
// 重要：Storage.clearDataForOrigin 是 origin-scoped、不影響其他 origin；
// 避免用 Network.clearBrowserCookies（browser-level，會清整個瀏覽器全部 cookies）。

const [pageId, quickText = '超级管理员', shotDir = '/tmp'] = process.argv.slice(2);
if (!pageId) { console.error('usage: node cdp-clear-and-relogin.mjs <pageId> [quickLoginText] [shotDir]'); process.exit(2); }

const ws = new WebSocket(`ws://127.0.0.1:9229/devtools/page/${pageId}`);
let nextId = 1;
const pending = new Map();
const eventListeners = new Map();

ws.addEventListener('message', (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id) {
    const cb = pending.get(msg.id);
    if (!cb) return;
    pending.delete(msg.id);
    msg.error ? cb.reject(new Error(JSON.stringify(msg.error))) : cb.resolve(msg.result);
  } else {
    (eventListeners.get(msg.method) || []).forEach((cb) => cb(msg.params));
  }
});
ws.addEventListener('error', (e) => { console.error('WS err:', e.message || e); process.exit(1); });

function send(method, params = {}) {
  const id = nextId++;
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
  });
}
function on(method, cb) {
  if (!eventListeners.has(method)) eventListeners.set(method, []);
  eventListeners.get(method).push(cb);
}
function waitFor(method, timeoutMs = 15000) {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error(`timeout waiting for ${method}`)), timeoutMs);
    on(method, (p) => { clearTimeout(t); resolve(p); });
  });
}

await new Promise((r) => ws.addEventListener('open', r, { once: true }));
await send('Page.enable');
await send('Runtime.enable');

console.log('--- clearing storage for localhost:31079 only (origin-scoped, 不影響其他 tab) ---');
await send('Storage.clearDataForOrigin', { origin: 'http://localhost:31079', storageTypes: 'all' });
// Also clear via Runtime (defensive,page 內 navigated 後再清一次)
await send('Runtime.evaluate', {
  expression: 'try { localStorage.clear(); sessionStorage.clear(); } catch(e) {}; document.cookie.split(";").forEach(c => { const eq = c.indexOf("="); document.cookie = (eq > -1 ? c.substr(0, eq) : c) + "=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/"; });',
});
console.log('storage cleared');

console.log('--- navigate /login ---');
const loadPromise = waitFor('Page.loadEventFired', 15000);
await send('Page.navigate', { url: 'http://localhost:31079/login' });
await loadPromise;
await new Promise((r) => setTimeout(r, 3000));   // SPA mount

const beforeState = await send('Runtime.evaluate', {
  expression: '({ title: document.title, url: location.href, inputCount: document.querySelectorAll("input").length, hasQuickLogin: !!Array.from(document.querySelectorAll("button")).find(b => b.textContent.trim() === ' + JSON.stringify(quickText) + ') })',
  returnByValue: true,
});
console.log('Pre-login state:', JSON.stringify(beforeState.result.value));

if (!beforeState.result.value.url.includes('/login')) {
  console.error('ERROR: not on /login after clear+navigate;router 沒 reset');
  process.exit(1);
}

const fs = await import('node:fs');
const shotLogin = await send('Page.captureScreenshot', { format: 'png' });
fs.writeFileSync(`${shotDir}/rev3-fresh-login.png`, Buffer.from(shotLogin.data, 'base64'));
console.log('Login screenshot:', `${shotDir}/rev3-fresh-login.png`);

console.log('--- click quick-login button ---');
const clickResult = await send('Runtime.evaluate', {
  expression: `(function() {
    const btn = Array.from(document.querySelectorAll('button')).find(b => b.textContent.trim() === ${JSON.stringify(quickText)});
    if (!btn) return { ok: false, error: 'button not found' };
    btn.click();
    return { ok: true, text: btn.textContent.trim() };
  })()`,
  returnByValue: true,
});
console.log('Click:', JSON.stringify(clickResult.result.value));

const startTs = Date.now();
let lastUrl = '/login';
while (Date.now() - startTs < 15000) {
  await new Promise((r) => setTimeout(r, 500));
  const cur = await send('Runtime.evaluate', { expression: 'location.href', returnByValue: true });
  if (cur.result.value !== lastUrl && !cur.result.value.endsWith('/login')) {
    console.log(`URL: ${lastUrl} -> ${cur.result.value}`);
    lastUrl = cur.result.value;
    if (!lastUrl.includes('/login')) break;
  } else {
    lastUrl = cur.result.value;
  }
}
console.log('Final URL:', lastUrl);

await new Promise((r) => setTimeout(r, 2000));
const postState = await send('Runtime.evaluate', {
  expression: `({
    title: document.title,
    url: location.href,
    hasMenu: document.querySelectorAll('.n-menu, [class*="layout-sider"], [class*="menu"]').length > 0,
    hasSuper: !!document.body.textContent.match(/Super/),
    elementCount: document.querySelectorAll('*').length,
  })`,
  returnByValue: true,
});
console.log('Post-login state:', JSON.stringify(postState.result.value, null, 2));

const shotDash = await send('Page.captureScreenshot', { format: 'png' });
fs.writeFileSync(`${shotDir}/rev3-fresh-postlogin.png`, Buffer.from(shotDash.data, 'base64'));
console.log('Dashboard screenshot:', `${shotDir}/rev3-fresh-postlogin.png`);

ws.close();
process.exit(0);
