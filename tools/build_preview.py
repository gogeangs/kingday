"""게임 미리보기(claude.ai Artifact)용 사본 만들기 — 그림을 묶음 파일 몇 개로 합침.

Artifact 한 개에는 파일을 512개까지만 올릴 수 있어서, 미리보기 사본에서만
- assets/ 의 그림 전부를 12MB 안팎의 묶음 파일(pv/b0.wasm, b1.wasm …)로 합치고
- 페이지가 열리면 묶음을 받아 그림마다 임시 주소(blob URL)를 만들어,
  게임 코드가 'assets/…' 경로로 부르는 곳(img·new Image·innerHTML·CSS url()·글꼴)을 그 주소로 바꿔 끼운다.
- 글꼴 4개는 HTML 안(data URI)에 넣고, 설치용 아이콘·manifest 링크는 뺀다. (실제 게임 index.html 은 그대로)

    python3 tools/build_preview.py <출력 폴더>

출력 폴더의 index.html 을 페이지로, pv/ 의 묶음 파일들을 함께 올린다(파일 수 = 묶음 수 + 1).
경로를 'assets/ui/'+이름 처럼 코드로 만들어도 됨 — 바꿔 끼우는 일은 실행 중에 함.
"""
import base64, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP = ('assets/icon/', 'assets/fonts/')  # 설치용 아이콘: 필요 없음 · 글꼴: 미리보기 화면이 blob 주소 글꼴을 막을 수 있어 HTML 안(data URI)에 넣음
CHUNK = 12 * 1024 * 1024  # 묶음 하나 크기 (Artifact 파일 하나 한도 15MB 안)
MIME = {'.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.woff2': 'font/woff2',
        '.svg': 'image/svg+xml', '.mp3': 'audio/mpeg', '.ogg': 'audio/ogg', '.wav': 'audio/wav'}

out = sys.argv[1]
os.makedirs(os.path.join(out, 'pv'), exist_ok=True)
for f in os.listdir(os.path.join(out, 'pv')):
    os.remove(os.path.join(out, 'pv', f))

# ── 묶음 만들기 ──
files = []
for d, _, fs in os.walk(os.path.join(ROOT, 'assets')):
    for f in sorted(fs):
        p = os.path.relpath(os.path.join(d, f), ROOT).replace(os.sep, '/')
        ext = os.path.splitext(f)[1].lower()
        if f.startswith('.') or p.startswith(SKIP) or ext not in MIME:
            continue
        files.append(p)
files.sort()
index, bundles, cur, size = {}, [], bytearray(), 0
for p in files:
    data = open(os.path.join(ROOT, p), 'rb').read()
    if cur and len(cur) + len(data) > CHUNK:
        bundles.append(cur); cur = bytearray()
    index[p] = [len(bundles), len(cur), len(data), MIME[os.path.splitext(p)[1].lower()]]
    cur += data
if cur:
    bundles.append(cur)
names = []
for i, b in enumerate(bundles):
    n = 'pv/b%d.wasm' % i  # 묶음 파일 (Artifact 가 올릴 수 있는 바이너리 확장자; 내용은 그림을 이어 붙인 것)
    open(os.path.join(out, n), 'wb').write(b)
    names.append(n)

# ── 페이지 바꾸기 ──
s = open(os.path.join(ROOT, 'index.html'), encoding='utf-8').read()
s = re.sub(r'<link[^>]+(?:manifest|apple-touch-icon|rel="icon"|rel="preload")[^>]*>\n?', '', s)
for f in sorted(os.listdir(os.path.join(ROOT, 'assets/fonts'))):
    if f.endswith('.woff2'):
        p = 'assets/fonts/' + f
        s = s.replace(p, 'data:font/woff2;base64,' + base64.b64encode(open(os.path.join(ROOT, p), 'rb').read()).decode())
s = s.replace('<style>', '<style type="text/pv">')  # 그림 주소를 바꾼 뒤 로더가 넣음
head, body = s.split('<body>', 1)
markup, rest = body.split('<script>', 1)
markup = markup.replace(' src="assets/', ' data-pvsrc="assets/')  # 처음 화면의 그림은 로더가 넣음
assert rest.count('</script>') == 1, '게임 스크립트가 하나여야 함'

LOADER = r'''<div id="pvload" style="position:fixed;inset:0;z-index:99999;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:12px;background:#0d1220;color:#eef1f8;font:600 15px system-ui,sans-serif"><div>미리보기 그림 불러오는 중…</div><div style="width:220px;height:8px;border-radius:4px;background:#29334f;overflow:hidden"><div id="pvbar" style="width:0;height:100%;background:#ffc94a;transition:width .2s"></div></div><small id="pvtxt" style="color:#97a2c3;font-weight:400"></small></div>
<script>
/* 미리보기 전용 로더 (tools/build_preview.py 가 넣음): 그림 묶음을 받아 'assets/…' 경로를 임시 주소로 바꿔 끼운 뒤 게임을 시작 */
(async()=>{
 const IDX=__IDX__,BUN=__BUN__,MAP={},bar=document.getElementById('pvbar'),txt=document.getElementById('pvtxt');
 const RE=/assets\/[A-Za-z0-9_\-\/.]+?\.(?:png|jpe?g|webp|woff2|svg|mp3|ogg|wav)/g;
 const fix=v=>typeof v==='string'&&v.indexOf('assets/')>=0?v.replace(RE,m=>MAP[m]||m):v;
 let done=0;const tot=BUN.length;
 let bufs;
 try{bufs=await Promise.all(BUN.map(n=>fetch(n).then(r=>{if(!r.ok)throw new Error(n+' '+r.status);return r.arrayBuffer()}).then(b=>{done++;bar.style.width=(done/tot*100)+'%';txt.textContent=done+' / '+tot;return b})))}
 catch(e){txt.textContent='불러오지 못했어요: '+e.message;return}
 for(const p in IDX){const[b,o,l,t]=IDX[p];MAP[p]=URL.createObjectURL(new Blob([new Uint8Array(bufs[b],o,l)],{type:t}))}
 /* 바꿔 끼우기: img.src(읽을 때는 원래 경로를 돌려줌), setAttribute, innerHTML·outerHTML·insertAdjacentHTML, style, fetch */
 const own=(o,k)=>{for(let p=o;p;p=Object.getPrototypeOf(p)){const d=Object.getOwnPropertyDescriptor(p,k);if(d)return[p,d]}return[]};
 {const[p,d]=own(HTMLImageElement.prototype,'src');Object.defineProperty(p,'src',{configurable:true,enumerable:d.enumerable,get(){return this.__pv??d.get.call(this)},set(v){this.__pv=MAP[v]?v:undefined;d.set.call(this,fix(v))}})}
 for(const k of['innerHTML','outerHTML']){const[p,d]=own(Element.prototype,k);if(d&&d.set)Object.defineProperty(p,k,{configurable:true,enumerable:d.enumerable,get:d.get,set(v){d.set.call(this,fix(v))}})}
 {const f=Element.prototype.insertAdjacentHTML;Element.prototype.insertAdjacentHTML=function(w,h){return f.call(this,w,fix(h))}}
 {const f=Element.prototype.setAttribute;Element.prototype.setAttribute=function(n,v){if(n==='src'&&this instanceof HTMLImageElement){this.src=v;return}return f.call(this,n,fix(v))}}
 {const f=CSSStyleDeclaration.prototype.setProperty;CSSStyleDeclaration.prototype.setProperty=function(n,v,pr){return f.call(this,n,fix(v),pr)};const[p,d]=own(CSSStyleDeclaration.prototype,'cssText');if(d&&d.set)Object.defineProperty(p,'cssText',{configurable:true,get:d.get,set(v){d.set.call(this,fix(v))}})}
 {const f=window.fetch;window.fetch=(u,o)=>f(typeof u==='string'?fix(u):u,o)}
 /* 처음 화면: CSS·그림·style 속성 */
 for(const st of document.querySelectorAll('style[type="text/pv"]')){const n=document.createElement('style');n.textContent=fix(st.textContent);st.replaceWith(n)}
 for(const el of document.querySelectorAll('[data-pvsrc]')){el.src=el.getAttribute('data-pvsrc');el.removeAttribute('data-pvsrc')}
 for(const el of document.querySelectorAll('[style*="assets/"]'))el.setAttribute('style',el.getAttribute('style'));
 /* 게임 시작 */
 const g=document.getElementById('pvgame'),sc=document.createElement('script');sc.textContent=g.textContent;g.remove();
 document.getElementById('pvload').remove();document.body.appendChild(sc);
})();
</script>
'''
LOADER = LOADER.replace('__IDX__', json.dumps(index, separators=(',', ':'))).replace('__BUN__', json.dumps(names))
s = head + '<body>' + markup + LOADER + '<script type="text/pv" id="pvgame">' + rest
open(os.path.join(out, 'index.html'), 'w', encoding='utf-8').write(s)
tot = sum(len(b) for b in bundles)
print(out, '· 페이지', round(len(s) / 1e6, 2), 'MB · 그림', len(files), '개 →', len(names), '묶음', round(tot / 1e6, 1), 'MB · 올릴 파일', len(names) + 1)
