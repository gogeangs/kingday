/* 왕이 되는 그날까지 — 오프라인 실행용 서비스 워커 (tools/build_sw.py가 만듦, 직접 고치지 말 것) */
const VERSION='__VERSION__';
const MAP=__MAP__;
const PAGE='kd-page',FILES='kd-files';
const base=self.registration.scope;
const key=(p,h)=>new URL(p,base).href+'?v='+h;
const pathOf=u=>{const s=new URL(base).pathname,p=new URL(u).pathname;return p.startsWith(s)?decodeURIComponent(p.slice(s.length)):null};

self.addEventListener('install',e=>{self.skipWaiting();e.waitUntil((async()=>{
  const pc=await caches.open(PAGE);try{await pc.add(new Request(base,{cache:'reload'}))}catch(_){}
  const fc=await caches.open(FILES),have=new Set((await fc.keys()).map(r=>r.url));
  const need=Object.entries(MAP).filter(([p,h])=>!have.has(key(p,h)));
  let i=0;const worker=async()=>{while(i<need.length){const[p,h]=need[i++];try{const r=await fetch(key(p,h));if(r.ok)await fc.put(key(p,h),r)}catch(_){}}};
  await Promise.all(Array.from({length:6},worker));
})())});

self.addEventListener('activate',e=>{e.waitUntil((async()=>{
  const keep=new Set(Object.entries(MAP).map(([p,h])=>key(p,h)));
  const fc=await caches.open(FILES);for(const r of await fc.keys())if(!keep.has(r.url))await fc.delete(r);
  for(const k of await caches.keys())if(k!==PAGE&&k!==FILES)await caches.delete(k);
  await self.clients.claim();
})())});

self.addEventListener('fetch',e=>{
  const req=e.request;if(req.method!=='GET')return;const url=new URL(req.url);if(url.origin!==location.origin)return;
  const p=pathOf(req.url);if(p==null)return;
  // 게임 화면: 인터넷이 되면 항상 최신, 안 되면(3초 넘게 걸리면) 저장본
  if(req.mode==='navigate'||p===''||p==='index.html'){e.respondWith((async()=>{
    const pc=await caches.open(PAGE);
    const net=fetch(req,{cache:'no-store'}).then(r=>{if(r.ok)pc.put(base,r.clone());return r});
    const timeout=new Promise(res=>setTimeout(()=>res(null),3000));
    try{const r=await Promise.race([net,timeout]);if(r)return r}catch(_){}
    return (await pc.match(base))||net})());return}
  const h=MAP[p];if(!h)return;
  e.respondWith((async()=>{const fc=await caches.open(FILES),k=key(p,h);const hit=await fc.match(k);if(hit)return hit;
    try{const r=await fetch(k);if(r.ok)fc.put(k,r.clone());return r}catch(_){return (await fc.match(k))||Response.error()}})());
});
