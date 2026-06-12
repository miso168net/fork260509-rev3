// usage: node cdp-login.mjs <pageId> [quickLoginText] [screenshotPath]
// click quick-login button + wait URL change + screenshot。
// pageId 必須完整 32 字元（rev2 000 文件 §5.6）。
// 來源：rev2 docs/superpowers/000-base-web-docker-bootstrap.md Appendix A.2（rev2 已實測），rev3 改截圖預設名。

const [pageId, quickText = '超级管理员', screenshotPath = '/tmp/rev3-postlogin.png'] = process.argv.slice(2);
if (!pageId) {
  console.error('usage: node cdp-login.mjs <pageId> [quickLoginText] [screenshotPath]');
  process.exit(2);
}

const ws = new WebSocket(`ws://127.0.0.1:9229/devtools/page/${pageId}`);
let nextId = 1;
const pending = new Map();

ws.addEventListener('message', (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id) {
    const cb = pending.get(msg.id);
    if (!cb) return;
    pending.delete(msg.id);
    msg.error ? cb.reject(new Error(JSON.stringify(msg.error))) : cb.resolve(msg.result);
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

await new Promise((r) => ws.addEventListener('open', r, { once: true }));
await send('Page.enable');
await send('Runtime.enable');

const before = await send('Runtime.evaluate', { expression: 'location.href', returnByValue: true });
console.log('Before click URL:', before.result.value);

const clickResult = await send('Runtime.evaluate', {
  expression: `(function() {
    const btn = Array.from(document.querySelectorAll('button')).find(
      (b) => b.textContent.trim() === ${JSON.stringify(quickText)}
    );
    if (!btn) return { ok: false, error: 'button not found' };
    btn.click();
    return { ok: true, text: btn.textContent.trim() };
  })()`,
  returnByValue: true,
});
console.log('Click result:', JSON.stringify(clickResult.result.value));
if (!clickResult.result.value.ok) { ws.close(); process.exit(1); }

const startTs = Date.now();
let lastUrl = before.result.value;
while (Date.now() - startTs < 15000) {
  await new Promise((r) => setTimeout(r, 500));
  const cur = await send('Runtime.evaluate', { expression: 'location.href', returnByValue: true });
  if (cur.result.value !== lastUrl) {
    console.log(`URL changed: ${lastUrl} -> ${cur.result.value}`);
    lastUrl = cur.result.value;
    if (!lastUrl.includes('/login')) break;
  }
}
console.log('Final URL:', lastUrl);

await new Promise((r) => setTimeout(r, 2000));    // 等 dashboard 渲染

const pageState = await send('Runtime.evaluate', {
  expression: `({
    title: document.title,
    url: location.href,
    bodyText: document.body.textContent.slice(0, 200).trim().replace(/\\s+/g, ' '),
    hasMenu: document.querySelectorAll('.n-menu, [class*="layout-sider"], [class*="menu"]').length > 0,
    hasUserName: !!document.body.textContent.match(/Super|超级管理员|admin/i),
    elementCount: document.querySelectorAll('*').length,
  })`,
  returnByValue: true,
});
console.log('Post-login state:', JSON.stringify(pageState.result.value, null, 2));

const shot = await send('Page.captureScreenshot', { format: 'png' });
const fs = await import('node:fs');
fs.writeFileSync(screenshotPath, Buffer.from(shot.data, 'base64'));
console.log('Screenshot:', screenshotPath);

ws.close();
process.exit(0);
