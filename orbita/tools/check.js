#!/usr/bin/env node
/* Yayin oncesi tek komutluk dogrulama:  node tools/check.js
   1) oyun betigi sozdizimi  2) tarayicida gercek oyun dongusu  3) gorsel olculeri
   4) hukuki sayfalar  5) yayin oncesi ayar uyarilari                              */
const fs = require('fs'), path = require('path'), cp = require('child_process');
const ROOT = path.join(__dirname, '..');
const CHROME = process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
let fail = 0, warn = 0;
const ok = m => console.log('  \x1b[32mOK\x1b[0m   ' + m);
const bad = m => { fail++; console.log('  \x1b[31mHATA\x1b[0m ' + m); };
const wrn = m => { warn++; console.log('  \x1b[33mUYARI\x1b[0m ' + m); };

console.log('\n1) Oyun betigi');
const html = fs.readFileSync(path.join(ROOT, 'www/index.html'), 'utf8');
const re = /<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g;
let m, blocks = 0;
while ((m = re.exec(html))) {
  blocks++;
  try { new Function(m[1]); } catch (e) { bad('betik blogu ' + blocks + ': ' + e.message); }
}
if (!fail) ok(blocks + ' betik blogu, sozdizimi temiz');

console.log('\n2) Tarayicida oyun dongusu (self-test)');
if (!fs.existsSync(CHROME)) {
  wrn('Chrome bulunamadi (' + CHROME + '). CHROME=/yol/chrome node tools/check.js ile calistir.');
} else {
  try {
    const out = cp.execSync(
      `"${CHROME}" --headless=new --no-sandbox --disable-gpu --virtual-time-budget=20000 ` +
      `--window-size=420,860 --dump-dom "file://${path.join(ROOT, 'www/index.html')}?selftest=1" 2>/dev/null`,
      { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
    const t = (out.match(/<title>([^<]*)<\/title>/) || [])[1] || '';
    if (t.startsWith('SELFTEST:OK')) ok(t.replace('SELFTEST:OK', 'oyun dongusu calisti —'));
    else bad('self-test basarisiz: ' + t);
  } catch (e) { bad('self-test calistirilamadi: ' + e.message); }
}

console.log('\n3) Magaza gorselleri');
const need = {
  'assets/icon-1024.png': [1024, 1024], 'assets/icon-512.png': [512, 512],
  'assets/feature-graphic-1024x500.png': [1024, 500], 'assets/splash-2732.png': [2732, 2732]
};
for (let i = 1; i <= 5; i++) {
  need['assets/screenshots/android-' + i + '-1080x1920.png'] = [1080, 1920];
  need['assets/screenshots/ios67-' + i + '-1290x2796.png'] = [1290, 2796];
}
for (const f in need) {
  const p = path.join(ROOT, f);
  if (!fs.existsSync(p)) { bad('eksik: ' + f); continue; }
  const d = fs.readFileSync(p).subarray(0, 33);
  const w = d.readUInt32BE(16), h = d.readUInt32BE(20), ctype = d[25];
  if (w !== need[f][0] || h !== need[f][1]) bad(f + ' olcusu ' + w + 'x' + h + ', beklenen ' + need[f].join('x'));
  else if (f === 'assets/icon-1024.png' && ctype === 6) bad('App Store ikonu alfa kanali icermemeli');
  else ok(f + ' ' + w + 'x' + h);
}

console.log('\n4) Hukuki ve destek sayfalari');
['docs/privacy.html', 'docs/gizlilik.html', 'docs/terms.html', 'docs/support.html', 'docs/index.html']
  .forEach(f => fs.existsSync(path.join(ROOT, f)) ? ok(f) : bad('eksik: ' + f));

console.log('\n5) Yayin oncesi ayarlar');
const cfg = JSON.parse(fs.readFileSync(path.join(ROOT, 'app.config.json'), 'utf8'));
if (/useTest:\s*true/.test(html)) wrn('CFG.ads.useTest = true — TEST reklamlari aktif. Yayindan once false yap.');
else {
  ok('gercek reklam kimlikleri aktif');
  ['android', 'ios'].forEach(p => ['app', 'interstitial', 'rewarded'].forEach(k => {
    if (!cfg.admob.real[p][k]) bad('app.config.json: admob.real.' + p + '.' + k + ' bos');
  }));
  if (/ca-app-pub-3940256099942544/.test(html)) bad('Kodda hala Google TEST reklam kimligi var!');
}
const mail = cfg.supportEmail;
if (!html.includes(mail)) wrn('www/index.html icindeki destek e-postasi app.config.json ile ayni degil — bash tools/set-identity.sh');
if (!fs.readFileSync(path.join(ROOT, 'docs/privacy.html'), 'utf8').includes(mail))
  wrn('docs/privacy.html icindeki e-posta app.config.json ile ayni degil');

console.log('\n' + (fail ? '\x1b[31m' + fail + ' hata' : '\x1b[32mHata yok') + '\x1b[0m, ' + warn + ' uyari.\n');
process.exit(fail ? 1 : 0);
