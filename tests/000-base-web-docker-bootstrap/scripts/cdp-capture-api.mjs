// usage: node cdp-capture-api.mjs <pageId> <outPath> [durationMs=60000] [--reload]
// 捕獲指定 tab 的 mock API 流量（XHR/Fetch → mock.apifox.cn 或 /proxy-default），寫 JSON。
// pageId 必須完整 32 字元（rev2 000 文件 §5.6）。
// --reload：attach 後先 Page.reload 一次（不需人工觸發流量，適合 smoke）。
// 重建版：早上 2026-06-12 session 的原始 capture script 未保存（session 事故），
// 此為等價重建；輸出 schema 對齊 base-web-capture.json（page 欄改用 document URL、非人工階段標記）。
// 跑法：先啟動本 script（背景收聽），再在該 tab 手動操作（登入、逛頁），時間到自動寫檔。

const args = process.argv.slice(2);
const doReload = args.includes('--reload');
const [pageId, outPath, durationArg] = args.filter((a) => a !== '--reload');
if (!pageId || !outPath) {
  console.error('usage: node cdp-capture-api.mjs <pageId> <outPath> [durationMs=60000] [--reload]');
  process.exit(2);
}
const durationMs = Number(durationArg) || 60000;

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

// 只收打向 mock（直連或 vite proxy 改寫前）的 API 請求
const API_RE = /mock\.apifox\.cn\/m1\/3109515-0-default|\/proxy-default\//;
function apiPath(url) {
  return url.replace(/^https?:\/\/[^/]+/, '').replace(/^\/m1\/3109515-0-default/, '').replace(/^\/proxy-default/, '');
}

await new Promise((r) => ws.addEventListener('open', r, { once: true }));
await send('Network.enable');
await send('Page.enable');

const reqs = new Map();   // requestId -> entry
const entries = [];

on('Network.requestWillBeSent', (p) => {
  if (!API_RE.test(p.request.url)) return;
  if (!['XHR', 'Fetch'].includes(p.type)) return;
  reqs.set(p.requestId, {
    method: p.request.method,
    url: apiPath(p.request.url),
    postData: p.request.postData ?? null,
    page: p.documentURL ? apiPath(p.documentURL) || p.documentURL : 'unknown',
  });
});
on('Network.responseReceived', (p) => {
  const e = reqs.get(p.requestId);
  if (!e) return;
  e.status = p.response.status;
  e.mime = p.response.mimeType;
});
on('Network.loadingFinished', async (p) => {
  const e = reqs.get(p.requestId);
  if (!e) return;
  reqs.delete(p.requestId);
  try {
    const body = await send('Network.getResponseBody', { requestId: p.requestId });
    e.body = body.base64Encoded ? Buffer.from(body.body, 'base64').toString('utf8') : body.body;
  } catch (err) {
    e.body = `<getResponseBody failed: ${err.message}>`;
  }
  entries.push(e);
  console.log(`captured [${entries.length}] ${e.method} ${e.url} ${e.status}`);
});
on('Network.loadingFailed', (p) => {
  const e = reqs.get(p.requestId);
  if (!e) return;
  reqs.delete(p.requestId);
  e.body = `<loadingFailed: ${p.errorText}>`;
  entries.push(e);
  console.log(`captured [${entries.length}] ${e.method} ${e.url} FAILED ${p.errorText}`);
});

if (doReload) {
  console.log('--reload: Page.reload 觸發 fresh 流量');
  await send('Page.reload');
}
console.log(`listening ${durationMs}ms — 請在該 tab 操作（登入、逛 /manage/* 頁）...`);
await new Promise((r) => setTimeout(r, durationMs));

const fs = await import('node:fs');
fs.writeFileSync(outPath, JSON.stringify({
  capturedAt: new Date().toISOString(),
  total: entries.length,
  entries,
}, null, 1));
console.log(`saved ${outPath} (${entries.length} entries)`);
ws.close();
process.exit(0);
