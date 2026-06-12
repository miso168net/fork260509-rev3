// usage: node cdp-nav.mjs <pageId> <url> [screenshotPath]
// navigate 既有 tab + dump form elements + screenshot。
// pageId 必須完整 32 字元（rev2 000 文件 §5.6）。
// 來源：rev2 docs/superpowers/000-base-web-docker-bootstrap.md Appendix A.1（rev2 已實測），rev3 改 port 31079。

const [pageId, url, screenshotPath = '/tmp/cdp-page.png'] = process.argv.slice(2);
if (!pageId || !url) {
  console.error('usage: node cdp-nav.mjs <pageId> <url> [screenshotPath]');
  process.exit(2);
}

const WS_URL = `ws://127.0.0.1:9229/devtools/page/${pageId}`;
const ws = new WebSocket(WS_URL);

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
function waitFor(method, timeoutMs = 30000) {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error(`timeout waiting for ${method}`)), timeoutMs);
    on(method, (params) => { clearTimeout(t); resolve(params); });
  });
}

await new Promise((r) => ws.addEventListener('open', r, { once: true }));
await send('Page.enable');
await send('Runtime.enable');

const loadPromise = waitFor('Page.loadEventFired', 30000);
await send('Page.navigate', { url });
await loadPromise;
await new Promise((r) => setTimeout(r, 3000));    // 等 vue SPA mount

const stateEval = await send('Runtime.evaluate', {
  expression: 'document.title + " | URL:" + location.href + " | inputs:" + document.querySelectorAll("input").length + " | buttons:" + document.querySelectorAll("button").length',
  returnByValue: true,
});
console.log('Page state:', stateEval.result.value);

const formDump = await send('Runtime.evaluate', {
  expression: `(function() {
    const inputs = Array.from(document.querySelectorAll('input')).map(i => ({
      type: i.type, name: i.name, id: i.id, placeholder: i.placeholder, className: i.className.slice(0, 60),
    }));
    const buttons = Array.from(document.querySelectorAll('button')).map(b => ({
      text: b.textContent.trim().slice(0, 30), type: b.type, className: b.className.slice(0, 60),
    }));
    return JSON.stringify({ inputs, buttons }, null, 2);
  })()`,
  returnByValue: true,
});
console.log('Form elements:');
console.log(formDump.result.value);

const shot = await send('Page.captureScreenshot', { format: 'png' });
const fs = await import('node:fs');
fs.writeFileSync(screenshotPath, Buffer.from(shot.data, 'base64'));
console.log('Screenshot saved:', screenshotPath);

ws.close();
process.exit(0);
