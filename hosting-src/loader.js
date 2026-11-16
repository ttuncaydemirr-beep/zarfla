/* ===== Zarfla davetli sayfası yükleyicisi (Firebase Hosting: https://zarfla-37da9.web.app/davetiye/) =====
   Motorun (invite.html) orijinal boot bloğunun yerine geçer; motorun görünümüne dokunmaz.
   Veri sözleşmesi: ?id=XXXXXXXXXXXX (12 karakter [A-Za-z0-9]) -> Firestore REST GET (API anahtarı yok).
   200: fields.data.stringValue = davetiye JSON dizesi; fields.plan.stringValue "free" | "paid".
   403/404: süresi dolmuş ya da hatalı bağlantı. Diğer hatalar / ağ hatası: tekrar dene. */
(function boot(){
  const FS="https://firestore.googleapis.com/v1/projects/zarfla-37da9/databases/(default)/documents/invites/";
  // Müzik ve yazı tipleri sayfayla aynı kökten (/music/, /fonts/) — CSP media-src/font-src 'self'.
  window.ZARFLA_MUSIC_BASE=location.origin+"/music/";
  // Süresi dolmuş / bulunamadı sayfasındaki sade "sen de hazırla" bağlantısı (motorun playUrl'i; tema yok → expired).
  const HOME=(typeof playUrl==="function")?playUrl("expired"):"https://play.google.com/store/apps/details?id=com.demirgamesstudio.zarfla";
  const T={
    tr:{title:"Davetiye · Zarfla",loading:"Davetiyeniz hazırlanıyor…",gone:"Bu davetiyenin süresi dolmuş ya da bağlantı hatalı.",err:"Bağlantı kurulamadı, tekrar deneyin",retry:"Tekrar",make:"Zarfla ile sen de 2 dakikada davetiye hazırla"},
    en:{title:"Invitation · Zarfla",loading:"Preparing your invitation…",gone:"This invitation has expired or the link is incorrect.",err:"Could not connect, please try again",retry:"Try again",make:"Make your own invitation with Zarfla in 2 minutes"},
    de:{title:"Einladung · Zarfla",loading:"Ihre Einladung wird vorbereitet …",gone:"Diese Einladung ist abgelaufen oder der Link ist fehlerhaft.",err:"Verbindung fehlgeschlagen, bitte erneut versuchen",retry:"Erneut versuchen",make:"Erstelle mit Zarfla in 2 Minuten deine eigene Einladung"},
    ar:{title:"دعوة · Zarfla",loading:"جارٍ تحضير دعوتك…",gone:"انتهت صلاحية هذه الدعوة أو أن الرابط غير صحيح.",err:"تعذّر الاتصال، حاول مرة أخرى",retry:"إعادة المحاولة",make:"حضّر دعوتك أنت أيضًا مع Zarfla في دقيقتين"}
  };
  function pickLang(){
    const n=(navigator.languages&&navigator.languages.length)?navigator.languages:[navigator.language||"tr"];
    for(let i=0;i<n.length;i++){const c=String(n[i]||"").slice(0,2).toLowerCase();if(T[c])return c}
    return "tr";
  }
  const LANG=pickLang();
  const NS="http://www.w3.org/2000/svg";
  function envelope(kind){
    // Zümrüt Zarf: kâğıt, zümrüt çizgi, altın yalnız mühür/süs.
    const s=document.createElementNS(NS,"svg");
    s.setAttribute("viewBox","0 0 160 120");s.setAttribute("class","zs-env zs-env--"+kind);s.setAttribute("aria-hidden","true");
    s.innerHTML='<rect x="8" y="22" width="144" height="92" rx="10" fill="#FBF7EF" stroke="#1F3D36" stroke-width="2.5"/>'+
      '<path d="M10 28 L80 74 L150 28" fill="none" stroke="#1F3D36" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"/>'+
      '<path d="M10 110 L62 66 M150 110 L98 66" fill="none" stroke="#1F3D36" stroke-width="2" stroke-linecap="round" opacity=".45"/>'+
      '<g class="zs-seal"><circle cx="80" cy="74" r="14" fill="#AD7F2E"/><circle cx="80" cy="74" r="10" fill="none" stroke="#F7F1E8" stroke-width="1.6" opacity=".75"/>'+
      '<path d="M80 68.5 L81.9 72.4 L86.2 73 L83.1 76 L83.8 80.3 L80 78.3 L76.2 80.3 L76.9 76 L73.8 73 L78.1 72.4Z" fill="#F7F1E8" opacity=".9"/></g>';
    return s;
  }
  function el(tag,cls,text){const e=document.createElement(tag);if(cls)e.className=cls;if(text!=null)e.textContent=text;return e}
  function setLang(l){
    document.documentElement.lang=l;document.documentElement.dir=(l==="ar")?"rtl":"ltr";document.title=T[l].title;
  }
  function show(kind,id){
    const t=T[LANG];setLang(LANG);
    const root=document.getElementById("root");root.textContent="";
    const wrap=el("div","zs");wrap.setAttribute("lang",LANG);wrap.setAttribute("dir",LANG==="ar"?"rtl":"ltr");
    const card=el("main","zs-card");
    card.appendChild(envelope(kind));
    if(kind==="loading"){
      const p=el("p","zs-t",t.loading);p.setAttribute("role","status");card.appendChild(p);
    }else if(kind==="gone"){
      const h=el("h1","zs-t",t.gone);card.appendChild(h);
    }else{
      const p=el("p","zs-t",t.err);p.setAttribute("role","alert");card.appendChild(p);
      const b=el("button","zs-btn",t.retry);b.type="button";b.addEventListener("click",function(){load(id)});card.appendChild(b);
    }
    wrap.appendChild(card);
    if(kind==="gone"){
      const f=el("p","zs-foot");const a=el("a",null,t.make);a.href=HOME;a.target="_blank";a.rel="noopener";f.appendChild(a);wrap.appendChild(f);
    }
    root.appendChild(wrap);
  }
  function render(doc){
    const f=doc&&doc.fields,ds=f&&f.data&&f.data.stringValue;
    if(typeof ds!=="string"){show("gone");return}
    let d;try{d=JSON.parse(ds)}catch(e){show("gone");return}
    if(!d||typeof d!=="object"||Array.isArray(d)){show("gone");return}
    // Plan: belge alanı (fields.plan) esastır; yoksa verideki plan. "paid"/"premium" -> alt yazı yok, diğerleri -> var.
    let p=f.plan&&typeof f.plan.stringValue==="string"?f.plan.stringValue:d.plan;
    d.plan=(p==="paid"||p==="premium")?"premium":"free";
    // Kişiye özel bağlantı (?g=Ad): ad YALNIZ adres çubuğundan okunur (motor temizler); sunucu verisindeki alan yok sayılır.
    d.guest=(typeof guestFromUrl==="function")?guestFromUrl(location.search,location.hash):"";
    if(window.renderInvite(d)){
      const l=document.documentElement.lang;document.documentElement.dir=(l==="ar")?"rtl":"ltr";
    }
  }
  function load(id){
    show("loading",id);
    const ctl=("AbortController" in window)?new AbortController():null;
    const to=setTimeout(function(){if(ctl)ctl.abort()},20000);
    fetch(FS+encodeURIComponent(id),{cache:"no-store",credentials:"omit",referrerPolicy:"no-referrer",signal:ctl?ctl.signal:undefined})
      .then(function(r){
        if(r.status===403||r.status===404){clearTimeout(to);show("gone");return}
        if(!r.ok)throw new Error("http "+r.status);
        return r.json().then(function(j){clearTimeout(to);render(j)});
      })
      .catch(function(){clearTimeout(to);show("error",id)});
  }
  const id=new URLSearchParams(location.search).get("id");
  if(!id||!/^[A-Za-z0-9]{12}$/.test(id)){show("gone");return}
  load(id);
})();
