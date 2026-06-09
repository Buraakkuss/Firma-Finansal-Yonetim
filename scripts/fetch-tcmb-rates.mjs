const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error('SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is missing. Add SUPABASE_SERVICE_ROLE_KEY in GitHub repository secrets.');
}

const TCMB_TIMEOUT_MS = Number(process.env.TCMB_TIMEOUT_MS || 18000);
const MAX_ARCHIVE_DAYS = Number(process.env.TCMB_MAX_ARCHIVE_DAYS || 12);

function sleep(ms) { return new Promise((resolve) => setTimeout(resolve, ms)); }
function turkeyNow() { return new Date(new Date().toLocaleString('en-US', { timeZone: 'Europe/Istanbul' })); }
function pad(n) { return String(n).padStart(2, '0'); }
function ymd(d) { return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`; }
function ym(d) { return `${d.getFullYear()}${pad(d.getMonth() + 1)}`; }
function dmyCompact(d) { return `${pad(d.getDate())}${pad(d.getMonth() + 1)}${d.getFullYear()}`; }
function dmyLabel(d) { return `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()}`; }
function addDays(d, days) {
  const x = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  x.setDate(x.getDate() + days);
  return x;
}
function targetDate() {
  const now = turkeyNow();
  const cutoff = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 15, 35, 0);
  const target = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  if (now < cutoff) return addDays(target, -1);
  return target;
}
function parseRateValue(value) {
  const raw = String(value || '').trim();
  if (!raw) return 0;
  if (raw.includes(',') && raw.includes('.')) return Number(raw.replace(/\./g, '').replace(',', '.')) || 0;
  if (raw.includes(',')) return Number(raw.replace(',', '.')) || 0;
  return Number(raw) || 0;
}
function parseRate(xml, code) {
  const re = new RegExp(`<Currency[^>]*(CurrencyCode|Kod)=["']${code}["'][\\s\\S]*?<ForexSelling>([^<]+)</ForexSelling>`, 'i');
  const m = xml.match(re);
  if (!m) return 0;
  return parseRateValue(m[2]);
}
function parseDateLabel(xml, fallbackDate) {
  const tarih = xml.match(/<Tarih_Date[^>]*Tarih=["']([^"']+)["']/i)?.[1];
  const date = xml.match(/<Tarih_Date[^>]*Date=["']([^"']+)["']/i)?.[1];
  return tarih || date || dmyLabel(fallbackDate);
}
async function fetchTextOnce(url) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(new Error(`Timeout after ${TCMB_TIMEOUT_MS}ms`)), TCMB_TIMEOUT_MS);
  try {
    const res = await fetch(url, {
      signal: controller.signal,
      headers: {
        'User-Agent': 'MarmaraTeknik-FirmaFinans/1.0 (+github-actions)',
        'Accept': 'application/xml,text/xml,*/*',
        'Cache-Control': 'no-cache'
      }
    });
    if (!res.ok) throw new Error(`${url} returned ${res.status}`);
    const txt = await res.text();
    if (!txt || txt.length < 100) throw new Error(`${url} returned empty XML`);
    return txt;
  } finally {
    clearTimeout(timer);
  }
}
async function fetchText(url, attempts = 2) {
  let lastError = null;
  for (let i = 1; i <= attempts; i++) {
    try {
      console.log(`TCMB fetch attempt ${i}/${attempts}: ${url}`);
      return await fetchTextOnce(url);
    } catch (err) {
      lastError = err;
      console.warn(`TCMB fetch failed attempt ${i}/${attempts}: ${err.message}`);
      if (i < attempts) await sleep(2500 * i);
    }
  }
  throw lastError;
}
function candidateUrls() {
  const target = targetDate();
  const urls = [];
  const today = ymd(turkeyNow());
  if (ymd(target) === today) {
    urls.push({ url: 'https://www.tcmb.gov.tr/kurlar/today.xml', date: target, attempts: 3 });
    urls.push({ url: 'http://www.tcmb.gov.tr/kurlar/today.xml', date: target, attempts: 1 });
  }
  for (let i = 0; i <= MAX_ARCHIVE_DAYS; i++) {
    const d = addDays(target, -i);
    urls.push({ url: `https://www.tcmb.gov.tr/kurlar/${ym(d)}/${dmyCompact(d)}.xml`, date: d, attempts: i === 0 ? 3 : 1 });
    urls.push({ url: `http://www.tcmb.gov.tr/kurlar/${ym(d)}/${dmyCompact(d)}.xml`, date: d, attempts: 1 });
  }
  return urls;
}
async function findTcmRates() {
  const urls = candidateUrls();
  const errors = [];
  for (const item of urls) {
    try {
      const xml = await fetchText(item.url, item.attempts);
      const eur = parseRate(xml, 'EUR');
      const usd = parseRate(xml, 'USD');
      if (eur > 0 && usd > 0) {
        return {
          rate_date: ymd(item.date),
          eur_selling: eur,
          usd_selling: usd,
          source: 'TCMB Forex Selling Rate - GitHub Actions',
          rate_date_label: parseDateLabel(xml, item.date),
          fetched_at: new Date().toISOString()
        };
      }
      errors.push(`EUR/USD not found in ${item.url}`);
    } catch (err) {
      errors.push(`${item.url}: ${err.message}`);
    }
  }
  throw new Error(`TCMB rate could not be fetched. Tried ${urls.length} URLs. Last errors: ${errors.slice(-5).join(' | ')}`);
}
async function saveToSupabase(payload) {
  const url = `${SUPABASE_URL}/rest/v1/firma_finans_fx_rate_cache?on_conflict=rate_date`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'resolution=merge-duplicates,return=representation'
    },
    body: JSON.stringify(payload)
  });
  const txt = await res.text();
  if (!res.ok) throw new Error(`Supabase upsert failed ${res.status}: ${txt}`);
  return txt;
}
async function getLatestCache() {
  const url = `${SUPABASE_URL}/rest/v1/firma_finans_fx_rate_cache?select=*&order=rate_date.desc&limit=1`;
  const res = await fetch(url, {
    headers: {
      'apikey': SUPABASE_SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      'Accept': 'application/json'
    }
  });
  const txt = await res.text();
  if (!res.ok) throw new Error(`Supabase latest cache read failed ${res.status}: ${txt}`);
  return JSON.parse(txt || '[]')[0] || null;
}

try {
  const payload = await findTcmRates();
  console.log('TCMB payload:', payload);
  const result = await saveToSupabase(payload);
  console.log('Supabase result:', result);
} catch (err) {
  console.warn('Live TCMB fetch failed:', err.message);
  const latest = await getLatestCache();
  if (latest) {
    console.warn('Existing cached TCMB rate will remain in use. Workflow exits successfully to avoid breaking daily automation. Latest cache:', latest);
    process.exit(0);
  }
  throw err;
}
