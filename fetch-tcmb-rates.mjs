const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error('SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is missing. Add SUPABASE_SERVICE_ROLE_KEY in GitHub repository secrets.');
}

function turkeyNow() {
  return new Date(new Date().toLocaleString('en-US', { timeZone: 'Europe/Istanbul' }));
}
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
function parseRate(xml, code) {
  const re = new RegExp(`<Currency[^>]*(CurrencyCode|Kod)=["']${code}["'][\\s\\S]*?<ForexSelling>([^<]+)</ForexSelling>`, 'i');
  const m = xml.match(re);
  if (!m) return 0;
  return Number(String(m[2]).trim().replace(/\./g, '').replace(',', '.')) || Number(String(m[2]).trim()) || 0;
}
function parseDateLabel(xml, fallbackDate) {
  const tarih = xml.match(/<Tarih_Date[^>]*Tarih=["']([^"']+)["']/i)?.[1];
  const date = xml.match(/<Tarih_Date[^>]*Date=["']([^"']+)["']/i)?.[1];
  return tarih || date || dmyLabel(fallbackDate);
}
async function fetchText(url) {
  const res = await fetch(url, {
    headers: {
      'User-Agent': 'MarmaraTeknik-FirmaFinans/1.0',
      'Accept': 'application/xml,text/xml,*/*'
    }
  });
  if (!res.ok) throw new Error(`${url} returned ${res.status}`);
  const txt = await res.text();
  if (!txt || txt.length < 100) throw new Error(`${url} returned empty XML`);
  return txt;
}
async function findTcmRates() {
  const target = targetDate();
  const urls = [];

  const todayYmd = ymd(turkeyNow());
  if (ymd(target) === todayYmd) {
    urls.push({ url: 'https://www.tcmb.gov.tr/kurlar/today.xml', date: target });
  }

  for (let i = 0; i <= 120; i++) {
    const d = addDays(target, -i);
    urls.push({ url: `https://www.tcmb.gov.tr/kurlar/${ym(d)}/${dmyCompact(d)}.xml`, date: d });
  }

  let lastError = null;
  for (const item of urls) {
    try {
      const xml = await fetchText(item.url);
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
      lastError = new Error(`EUR/USD not found in ${item.url}`);
    } catch (err) {
      lastError = err;
    }
  }
  throw lastError || new Error('TCMB rate could not be fetched.');
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

const payload = await findTcmRates();
console.log('TCMB payload:', payload);
const result = await saveToSupabase(payload);
console.log('Supabase result:', result);
