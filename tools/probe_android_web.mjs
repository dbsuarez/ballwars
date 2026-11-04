// Read-only metrics for the localhost Ball Wars tab on a USB Android phone.
// Prerequisite: adb forward tcp:9223 localabstract:chrome_devtools_remote
// Never reads cookies, storage, credentials or unrelated tabs.
const tabs = await (await fetch('http://127.0.0.1:9223/json')).json();
let selected;
for (const tab of tabs.filter(t => t.type === 'page' && t.url === 'http://127.0.0.1:8334/ballwars/')) {
  const socket = new WebSocket(tab.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
  let sequence = 0;
  const pending = new Map();
  socket.onmessage = ({data}) => {
    const message = JSON.parse(data);
    const entry = pending.get(message.id);
    if (!entry) return;
    pending.delete(message.id);
    clearTimeout(entry.timer);
    message.error ? entry.reject(new Error(message.error.message)) : entry.resolve(message.result);
  };
  const call = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`${method} timeout`)); }, 15000);
    pending.set(id, {resolve, reject, timer});
    socket.send(JSON.stringify({id, method, params}));
  });
  const evaluate = async (expression, awaitPromise = false) => {
    const result = await call('Runtime.evaluate', {expression, awaitPromise, returnByValue: true});
    if (result.exceptionDetails) throw new Error('Page probe failed');
    return result.result.value;
  };
  const viewport = await evaluate('({width:innerWidth,height:innerHeight,dpr:devicePixelRatio,visibility:document.visibilityState})');
  if (viewport.visibility !== 'visible') { socket.close(); continue; }
  selected = true;
  await call('Performance.enable');
  const before = await call('Performance.getMetrics');
  const intervals = await evaluate(`new Promise(resolve => {
    const values = []; let previous; const start = performance.now();
    function frame(now) { if (previous !== undefined) values.push(now-previous); previous=now;
      if (now-start < 5000) requestAnimationFrame(frame); else resolve(values); }
    requestAnimationFrame(frame);
  })`, true);
  const after = await call('Performance.getMetrics');
  const metrics = data => Object.fromEntries(data.metrics.filter(m => ['JSHeapUsedSize','JSHeapTotalSize','TaskDuration','Timestamp'].includes(m.name)).map(m=>[m.name,m.value]));
  intervals.sort((a,b)=>a-b);
  console.log(JSON.stringify({checked_at: new Date().toISOString(), viewport, before:metrics(before), after:metrics(after),
    raf_scheduling: {samples:intervals.length,p50_ms:intervals[Math.floor(intervals.length*.5)],p95_ms:intervals[Math.floor(intervals.length*.95)]},
    limitation:'Browser rAF scheduling and JS heap only; not GPU frame timings or total process memory.'},null,2));
  socket.close();
  break;
}
if (!selected) throw new Error('No visible localhost Ball Wars tab; leave the test match in the foreground.');
