// Uzun ad / uzun tek sözcük: 13 düzen ve 20 açılış kapısında hiçbir metin kabının dışına taşmaz, ekran kenarında kırpılmaz;
// boş tarih/saat/mekân/mesaj alanları ve tek başına kalan karakter ("y", "—") çizilmez.
// Başsız Chrome gerekir (CI'da ubuntu-latest'te var); yoksa test atlanır.
// Çalıştırma: node --test test/js/longnames.test.mjs
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

const html = readFileSync(new URL('../../assets/invite/invite.html', import.meta.url), 'utf8');

function findChrome() {
  for (const b of [process.env.CHROME_BIN, 'google-chrome', 'google-chrome-stable', 'chromium', 'chromium-browser']) {
    if (!b) continue;
    try {
      execFileSync(b, ['--version'], { stdio: 'ignore' });
      return b;
    } catch {}
  }
  return null;
}
const chrome = findChrome();

const LAYOUTS = ['klasik', 'kemer', 'monogram', 'editoryal', 'kartpostal', 'zamancizelgesi', 'bilet', 'galeri', 'mektup', 'davetkarti', 'minimal', 'gece', 'hikaye'];
const OPENINGS = ['door', 'env', 'perde', 'kitap', 'muhur', 'isik', 'sarmasik', 'cicek', 'kurdele', 'kelebek', 'yildiz', 'pencere', 'zarfacil', 'muhurkir', 'kagitkatla', 'parilti', 'lale', 'fener', 'kapikemer', 'konfeti'];
const NAMES = [
  { lang: 'tr', n1: 'Maximiliano-Alejandro', n2: 'vgffghgggggggggggg' },
  { lang: 'en', n1: 'vgffghgggggggggggg', n2: 'Maximiliano-Alejandro' },
  { lang: 'ar', n1: 'عبدالرحمنبنمحمدالفاطمي', n2: 'محمد عبد الرحمن بن سليمان الفاطمي' },
];
const LONGWORD = 'Supercalifragilisticexpialidocious_Supercalifragilistic';

function harness(cases) {
  const script = `
  const CASES=${JSON.stringify(cases)},LONGWORD=${JSON.stringify(LONGWORD)};
  const wait=ms=>new Promise(r=>setTimeout(r,ms));
  const ALLOW=".mono-ini,.seal-disc,.w3-wax,.hk-av,.day,.countdown,.mn-grid,.ms";
  const desc=el=>el.tagName.toLowerCase()+(el.className&&el.className.baseVal===undefined?"."+String(el.className).split(" ").join("."):"");
  function mk(c){
    const full=c.full;
    return {id:"inv1abcd",type:"kina",theme:c.theme||"papatya",lang:c.lang,n1:c.n1,n2:c.n2,host:full?LONGWORD:"",msg:full?LONGWORD+" "+LONGWORD:"",
      date:full?"2027-06-12":"",time:full?"19:00":"",end:"",venue:full?LONGWORD:"",address:full?LONGWORD:"",wa:"905321234567",opening:c.opening,layout:c.layout,cover:"",photos:[],
      program:full?[{t:"19:00",x:LONGWORD}]:[],notes:full?[LONGWORD]:[],status:"live",plan:full?"premium":"free",created:1760000000000,
      guest:full?"Maximiliano-Alejandro Fernandez-Montenegro":"",
      gift:full?{holder:LONGWORD,bank:LONGWORD,iban:"TR330006100519786457841326"}:undefined,live:full?{url:"https://youtu.be/abc123",note:LONGWORD}:undefined};
  }
  (async()=>{
    const out=[];
    for(const c of CASES){
      const f=document.createElement("iframe");f.style.cssText="width:"+c.w+"px;height:700px;border:0;display:block";
      f.srcdoc=document.getElementById("src").textContent.replace(/<\\\\\\/script>/g,"<\\/script>");
      document.body.appendChild(f);await new Promise(r=>f.onload=r);
      const W=f.contentWindow,D=f.contentDocument;
      W.renderInvite(mk(c));await wait(160);
      const host=D.querySelector(".inv-host"),issues=[],texts=[];
      for(const el of host.querySelectorAll("*")){
        if(el.closest("svg"))continue;
        const own=[...el.childNodes].filter(n=>n.nodeType===3&&n.textContent.trim());
        if(!own.length)continue;
        const cs=W.getComputedStyle(el);if(cs.display==="none"||cs.visibility==="hidden")continue;
        if(el.closest("[hidden],.thanks,.ierr,.zf-toast,.lb"))continue;
        own.forEach(n=>texts.push({t:n.textContent.trim(),cls:desc(el),allow:!!el.closest(ALLOW)}));
        if(el.clientWidth>0&&el.scrollWidth>el.clientWidth+1)issues.push("taşma "+desc(el)+" "+el.scrollWidth+">"+el.clientWidth+" ["+own[0].textContent.trim().slice(0,20)+"]");
        const r=D.createRange();r.selectNodeContents(el);const rc=r.getBoundingClientRect();
        if(rc.width>0&&(rc.right>W.innerWidth+1||rc.left<-1))issues.push("ekran dışı "+desc(el)+" "+Math.round(rc.left)+".."+Math.round(rc.right)+" ["+own[0].textContent.trim().slice(0,20)+"]");
      }
      const scr=D.querySelector(".inv-scroll");
      if(scr.scrollWidth>scr.clientWidth+1)issues.push("yatay kaydırma");
      const stray=texts.filter(x=>!x.allow&&(/^\\p{L}$/u.test(x.t)||x.t==="—")).map(x=>x.cls+"="+x.t);
      const bare=c.full?[]:texts.filter(x=>/(^|\\.)sub/.test(x.cls)&&/·\\s*$|^\\s*·/.test(x.t)).map(x=>x.cls+"="+x.t);
      out.push({tag:c.layout+"/"+c.opening+" "+c.lang+" "+c.w+"px "+(c.full?"dolu":"bos"),issues,stray:stray.concat(bare)});
      f.remove();
    }
    document.getElementById("res").textContent=JSON.stringify(out);
  })();`;
  return `<!doctype html><meta charset="utf-8"><body><script type="text/plain" id="src">${html.replace(/<\/script>/g, '<\\/script>')}</script><pre id="res">PENDING</pre><script>${script}</script></body>`;
}

function run(cases) {
  const dir = mkdtempSync(join(tmpdir(), 'zflong-'));
  try {
    const file = join(dir, 'h.html');
    writeFileSync(file, harness(cases));
    const dom = execFileSync(chrome, ['--headless=new', '--no-sandbox', '--disable-gpu', '--allow-file-access-from-files',
      '--virtual-time-budget=300000', '--dump-dom', 'file://' + file], { encoding: 'utf8', maxBuffer: 1 << 28, timeout: 400000 });
    const m = dom.match(/<pre id="res">([\s\S]*?)<\/pre>/);
    assert.ok(m && m[1] !== 'PENDING', 'ölçüm tamamlanmadı');
    return JSON.parse(m[1].replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&amp;/g, '&'));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function matrix(layouts, openings, widths) {
  const cs = [];
  for (const layout of layouts) for (const opening of openings) for (const nm of NAMES) for (const w of widths) for (const full of [true, false]) {
    cs.push({ layout, opening, w, full, ...nm, theme: layout === 'kemer' ? 'papatya' : undefined });
  }
  return cs;
}

function check(res, n) {
  assert.equal(res.length, n);
  const bad = res.filter((r) => r.issues.length || r.stray.length).map((r) => `${r.tag}: ${r.issues.slice(0, 4).join(' | ')} ${r.stray.length ? 'TEK KARAKTER: ' + r.stray.join(',') : ''}`);
  assert.deepEqual(bad, []);
}

test('13 düzen: uzun adlar 320 ve 430 px genişlikte taşmaz; boş alanlar çizilmez', { skip: !chrome && 'Chrome yok' }, () => {
  const cs = matrix(LAYOUTS, ['door'], [320, 430]);
  check(run(cs), cs.length);
});

test('20 açılış kapısı: uzun adlar 320 px genişlikte taşmaz', { skip: !chrome && 'Chrome yok' }, () => {
  const cs = matrix(['kemer'], OPENINGS, [320]);
  check(run(cs), cs.length);
});

test('zarf açılışı + her düzen: uzun ad/davetli adı sığar', { skip: !chrome && 'Chrome yok' }, () => {
  const cs = matrix(LAYOUTS, ['zarfacil'], [320]);
  check(run(cs), cs.length);
});
