#!/usr/bin/env bash
# app.config.json icindeki degerleri tum dosyalara yazar.
# Kullanim: bash tools/set-identity.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node -e '
const fs=require("fs"),p=process.argv[1];
const c=JSON.parse(fs.readFileSync(p+"/app.config.json","utf8"));
const files=["www/index.html","docs/index.html","docs/privacy.html","docs/gizlilik.html",
             "docs/terms.html","docs/support.html","capacitor.config.json","store/google-play.md","store/app-store.md"];
const OLD_MAIL="t.burakkus@gmail.com", OLD_URL="https://buraakkuss.github.io/orbita-game", OLD_ID="com.kusgrup.orbita";
for(const f of files){
  const fp=p+"/"+f; if(!fs.existsSync(fp)) continue;
  let s=fs.readFileSync(fp,"utf8");
  s=s.split(OLD_MAIL).join(c.supportEmail).split(OLD_URL).join(c.pagesBaseUrl).split(OLD_ID).join(c.bundleId);
  fs.writeFileSync(fp,s);
}
let g=fs.readFileSync(p+"/www/index.html","utf8");
g=g.replace(/version: '"'"'[^'"'"']*'"'"'/, "version: '"'"'"+c.version+"'"'"'");
g=g.replace(/useTest: (true|false)/, "useTest: "+(c.admob.useTest?"true":"false"));
for(const plat of ["android","ios"]){
  for(const k of ["app","interstitial","rewarded"]){
    const v=c.admob.real[plat][k]; if(!v) continue;
    const re=new RegExp("(real:[\\\\s\\\\S]*?"+plat+":\\\\s*\\\\{[^}]*?"+k+":\\\\s*'"'"')[^'"'"']*("'"'"')");
    g=g.replace(re,"$1"+v+"$2");
  }
}
fs.writeFileSync(p+"/www/index.html",g);
console.log("kimlik guncellendi:",c.bundleId,c.supportEmail,c.pagesBaseUrl);
' "$ROOT"
