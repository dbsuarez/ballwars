// Headless local-only release diagnostic. Node 22+, installed Chrome. No user browser profile.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {spawn} from 'node:child_process';
const root=path.resolve('build/startup-profile');
const delay=Number(process.env.STARTUP_ASSET_DELAY_MS ?? 60);
let active=0, peak=0, assetRequests=0;
const mime={'.html':'text/html','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.ttf':'font/ttf','.otf':'font/otf','.png':'image/png'};
const server=http.createServer((req,res)=>{
 const url=new URL(req.url,'http://127.0.0.1');
 const file=path.resolve(root,'.'+decodeURIComponent(url.pathname==='/'?'/index.html':url.pathname));
 if(!file.startsWith(root+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);res.end();return;}
 const asset=file.includes(path.join('assets','assets','sprites')) && ['.json','.png'].includes(path.extname(file));
 if(asset){active++;assetRequests++;peak=Math.max(peak,active);}
 setTimeout(()=>{
  res.setHeader('Content-Type',mime[path.extname(file)]??'application/octet-stream');res.setHeader('Cache-Control','no-store');
  if(asset)res.on('finish',()=>active--);
  fs.createReadStream(file).pipe(res);
 },asset?delay:0);
});
await new Promise(resolve=>server.listen(8357,'127.0.0.1',resolve));
const chrome=spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',[
 '--headless=new','--remote-debugging-port=9357',`--user-data-dir=${path.resolve('build/startup-chrome-'+Date.now())}`,
 '--no-first-run','--no-default-browser-check','--disable-background-timer-throttling','about:blank'
],{windowsHide:true,stdio:'ignore'});
let socket;
try{
 let targets;
 for(let i=0;i<100;i++){try{targets=await(await fetch('http://127.0.0.1:9357/json')).json();break;}catch{await new Promise(r=>setTimeout(r,100));}}
 if(!targets)throw new Error('Chrome debugging endpoint unavailable');
 const target=targets.find(t=>t.type==='page');socket=new WebSocket(target.webSocketDebuggerUrl);
 await new Promise((resolve,reject)=>{socket.onopen=resolve;socket.onerror=reject;});
 let sequence=0;const pending=new Map();
 socket.onmessage=e=>{const m=JSON.parse(e.data);if(m.id&&pending.has(m.id)){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(m.error):p.resolve(m.result);}};
 const call=(method,params={})=>new Promise((resolve,reject)=>{const id=++sequence;pending.set(id,{resolve,reject});socket.send(JSON.stringify({id,method,params}));});
 await call('Page.enable');await call('Runtime.enable');await call('Network.enable');await call('Network.setCacheDisabled',{cacheDisabled:true});await call('Network.setBypassServiceWorker',{bypass:true});
 const runs=[];
 for(const serial of [true,false]){
  active=0;peak=0;assetRequests=0;
  await call('Page.navigate',{url:`http://127.0.0.1:8357/?serial=${serial?1:0}`});
  let report;
  for(let i=0;i<240;i++){
   const result=await call('Runtime.evaluate',{expression:'window.__ballwarsStartupReport || null',returnByValue:true});
   if(result.result.value){const candidate=JSON.parse(result.result.value);if(candidate.serializedRequests===serial){report=candidate;break;}}
   await new Promise(r=>setTimeout(r,250));
  }
  if(!report)throw new Error('Profile did not complete in 60 seconds');
  runs.push({...report,peakAssetRequests:peak,totalSpriteRequests:assetRequests});
 }
 const output={simulatedAssetLatencyMs:delay,runs};
 fs.writeFileSync('build/startup-browser-results.json',JSON.stringify(output,null,2));console.log(JSON.stringify(output));
}finally{socket?.close();chrome.kill();await new Promise(resolve=>server.close(resolve));}
