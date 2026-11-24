// RSVP satırı ("Katılıyorum / Katılamıyorum") 320 px genişlikte, 7 dilde ve büyütülmüş yazıda taşmamalı/kırpılmamalı.
// Başsız Chrome gerekir (CI'da ubuntu-latest'te var); yoksa test atlanır.
// Çalıştırma: node --test test/js/rsvp_layout.test.mjs
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

const LANGS = ['tr', 'en', 'de', 'ar', 'es', 'pt', 'id'];
const WIDTHS = [320, 360];
const BOOSTS = [1, 1.5]; // 1.5: sistem metin yakınlaştırmasını taklit eder (tüm yazı tipi boyutları çarpılır)

function harness() {
  const esc = html.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
  const script = `
  const LANGS=${JSON.stringify(LANGS)},WIDTHS=${JSON.stringify(WIDTHS)},BOOSTS=${JSON.stringify(BOOSTS)};
  const mk=l=>({id:"inv1abcd",type:"dugun",theme:"papatya",lang:l,n1:"Ali",n2:"Ayse",host:"",msg:"",date:"2027-06-12",time:"19:00",end:"",venue:"Bahce",address:"",wa:"905321234567",opening:"door",layout:"klasik",cover:"",photos:[],program:[],notes:[],status:"live",plan:"free",created:1760000000000});
  const wait=ms=>new Promise(r=>setTimeout(r,ms));
  (async()=>{
    const out=[];
    for(const w of WIDTHS)for(const b of BOOSTS)for(const l of LANGS){
      const f=document.createElement("iframe");f.style.cssText="width:"+w+"px;height:640px;border:0;display:block";f.srcdoc=document.getElementById("src").textContent;
      document.body.appendChild(f);
      await new Promise(r=>f.onload=r);await wait(50);
      const W=f.contentWindow,D=f.contentDocument;
      W.renderInvite(mk(l));await wait(60);
      if(b!==1){for(const el of D.querySelectorAll(".inv *")){const fs=parseFloat(W.getComputedStyle(el).fontSize);if(fs)el.style.fontSize=(fs*b)+"px"}}
      const sec=D.querySelector("[data-rsvpsec]");
      const labs=[...D.querySelectorAll(".choice label")];
      const rs=labs.map(x=>x.getBoundingClientRect());
      const scr=D.querySelector(".inv-scroll");
      out.push({l,w,b,vw:W.innerWidth,sec:sec.getBoundingClientRect().width,rects:rs.map(x=>[x.left,x.right,x.width]),
        clip:labs.map(x=>x.scrollWidth>x.clientWidth+1),secR:sec.getBoundingClientRect().right,hscroll:scr.scrollWidth>scr.clientWidth+1});
      f.remove();
    }
    document.getElementById("res").textContent=JSON.stringify(out);
  })();`;
  return `<!doctype html><meta charset="utf-8"><body><script type="text/plain" id="src">${html.replace(/<\/script>/g, '<\\/script>')}</script><pre id="res">PENDING</pre><script>${script}</script></body>`;
}

test('RSVP düğmeleri 320/360 px ve %150 yazıda 7 dilde taşmaz, kırpılmaz, eşit genişliktedir', { skip: !chrome && 'Chrome yok' }, () => {
  const dir = mkdtempSync(join(tmpdir(), 'zfrsvp-'));
  try {
    // <script type=text/plain> içindeki HTML'de "</script>" kaçışı: srcdoc'a verilirken geri çevrilir.
    let h = harness();
    h = h.replace('f.srcdoc=document.getElementById("src").textContent;', 'f.srcdoc=document.getElementById("src").textContent.replace(/<\\\\\\/script>/g,"<\\/script>");');
    const file = join(dir, 'h.html');
    writeFileSync(file, h);
    const dom = execFileSync(chrome, ['--headless=new', '--no-sandbox', '--disable-gpu', '--allow-file-access-from-files',
      '--virtual-time-budget=60000', '--dump-dom', 'file://' + file], { encoding: 'utf8', maxBuffer: 1 << 28, timeout: 120000 });
    const m = dom.match(/<pre id="res">([\s\S]*?)<\/pre>/);
    assert.ok(m && m[1] !== 'PENDING', 'ölçüm tamamlanmadı');
    const res = JSON.parse(m[1].replace(/&quot;/g, '"').replace(/&amp;/g, '&'));
    assert.equal(res.length, LANGS.length * WIDTHS.length * BOOSTS.length);
    for (const r of res) {
      const tag = `${r.l} ${r.w}px x${r.b}`;
      assert.equal(r.rects.length, 2, tag);
      for (const [l, rt] of r.rects) {
        assert.ok(l >= -0.5 && rt <= r.vw + 0.5, `${tag}: düğme ekran dışında (${l}..${rt}, vw ${r.vw})`);
        assert.ok(rt <= r.secR + 0.5 && l >= r.secR - r.sec - 0.5, `${tag}: düğme kartın dışında`);
      }
      assert.ok(Math.abs(r.rects[0][2] - r.rects[1][2]) < 1, `${tag}: iki düğme eşit genişlikte değil`);
      assert.deepEqual(r.clip, [false, false], `${tag}: metin kırpılıyor`);
      assert.equal(r.hscroll, false, `${tag}: yatay kaydırma oluştu`);
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
