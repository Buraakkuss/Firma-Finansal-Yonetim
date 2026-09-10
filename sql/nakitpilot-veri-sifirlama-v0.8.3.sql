-- ===========================================================================
-- NakitPilot v0.8.3 — Tüm firmalar için işlem verisi sıfırlama
-- ---------------------------------------------------------------------------
-- Supabase > SQL Editor'a tamamını yapıştırıp bir kez Run deyin.
-- Tek parçadır, tek işlemde (transaction) çalışır; hata olursa hiçbir şey değişmez.
--
-- SİLİNENLER (girdi/çıktı ve türetilen her şey):
--   • Tamamlanmış gelir ve gider kayıtları
--   • Gelecekteki kesin gelir/gider ve sabit kalemler
--   • Tahmini gelir/gider kalemleri
--   • Döviz dönüşümleri, kredi kartı ödemeleri
--   • Banka hesap hareketleri, transferler, KMH hareketleri,
--     kart hareketleri, taksitler, yatırım hareketleri, ters kayıtlar
--   • Banka hesaplarının açılış bakiyesi ve bloke tutarı  → 0
--   • KMH açılış borcu                                    → 0
--   • Kredi kartlarının borç/provizyon/taksit/asgari alanları → 0
--
-- KORUNANLAR (tanım ve ayar; yeniden yazmak zorunda kalmayın):
--   • Firmalar, kullanıcılar, roller, finans izinleri
--   • Banka tanımları, hesap tanımları (IBAN, tür, para birimi)
--   • Kredi kartı tanımları (limit, son 4 hane, kesim/son ödeme günü)
--   • KMH tanımları (limit, faiz oranı, bağlı hesap)
--   • Proje Takip (MT Pro) kayıtları
--   • Kategori listeleri — banka içi hareketi gelir/gider gibi gösteren
--     yanıltıcı kategoriler hariç (aşağıda 3. adım)
--
-- Normalize finans tabloları (bank_accounts, credit_card_transactions, ...)
-- company_data üzerindeki trg_company_data_banking_sync tetikleyicisi ile
-- otomatik olarak aynılanır; onlar için ayrıca komut çalıştırmanıza gerek yok.
--
-- GERİ DÖNÜŞ: 1. adım her firmanın mevcut verisini company_backups tablosuna
-- yazar. Geri almak için bu dosyanın sonundaki GERİ ALMA bloğuna bakın.
-- ===========================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1) Emniyet yedeği — sıfırlamadan önce mevcut hâli sakla
-- ---------------------------------------------------------------------------
insert into public.company_backups(company_id, backup_name, data, created_by)
select cd.company_id,
       'v0.8.3 sifirlama oncesi otomatik yedek - '
         || to_char(now() at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'),
       cd.data,
       cd.updated_by
from public.company_data cd;

-- ---------------------------------------------------------------------------
-- 2) İşlem verisini temizle, tanımları koru
-- ---------------------------------------------------------------------------
update public.company_data cd
set data = coalesce(cd.data, '{}'::jsonb)
  || jsonb_build_object(
       'income',             '[]'::jsonb,
       'expense',            '[]'::jsonb,
       'fixed',              '[]'::jsonb,
       'forecast',           '[]'::jsonb,
       'fxTransfers',        '[]'::jsonb,
       'creditCardPayments', '[]'::jsonb,

       -- Kart tanımları kalır, para alanları sıfırlanır.
       'creditCards', coalesce((
         select jsonb_agg(
                  c || jsonb_build_object(
                    'openingDebt',          0,
                    'previousDebt',         0,
                    'minimumPayment',       0,
                    'installmentTotal',     0,
                    'pendingAuthorization', 0)
                  order by ord)
         from jsonb_array_elements(coalesce(cd.data->'creditCards', '[]'::jsonb))
              with ordinality as t(c, ord)
       ), '[]'::jsonb),

       'banking', coalesce(cd.data->'banking', '{}'::jsonb)
         || jsonb_build_object(
              -- Hesap tanımları kalır, bakiyeler sıfırlanır.
              'accounts', coalesce((
                select jsonb_agg(
                         a || jsonb_build_object(
                           'openingBalance', 0,
                           'blockedAmount',  0)
                         order by ord)
                from jsonb_array_elements(coalesce(cd.data#>'{banking,accounts}', '[]'::jsonb))
                     with ordinality as t(a, ord)
              ), '[]'::jsonb),

              -- KMH tanımları kalır (limit, faiz, bağlı hesap), borç sıfırlanır.
              'overdrafts', coalesce((
                select jsonb_agg(o || jsonb_build_object('openingDebt', 0) order by ord)
                from jsonb_array_elements(coalesce(cd.data#>'{banking,overdrafts}', '[]'::jsonb))
                     with ordinality as t(o, ord)
              ), '[]'::jsonb),

              'accountTransactions',    '[]'::jsonb,
              'transfers',              '[]'::jsonb,
              'overdraftTransactions',  '[]'::jsonb,
              'cardTransactions',       '[]'::jsonb,
              'cardInstallments',       '[]'::jsonb,
              'investmentTransactions', '[]'::jsonb,
              'reversals',              '[]'::jsonb
            ),

-- ---------------------------------------------------------------------------
-- 3) Yanıltıcı kategorileri kaldır
-- ---------------------------------------------------------------------------
-- KMH kullanımı ve kredi kartı borcu ödemesi gelir/gider DEĞİLDİR; bunlar
-- varlıklar arası harekettir ve Banka Merkezi üzerinden işlenmelidir
-- (docs/03 iş kuralları 3, 5 ve 6). Bu kategoriler listede kaldığı sürece
-- aynı hata tekrar edilir, bu yüzden temizleniyor.
-- "KMH FAİZ ÖDEMESİ" ve "KOMİSYON GİDERLERİ" KALIR — faiz ve banka masrafı
-- gerçek giderdir (iş kuralı 7).
       'categories', jsonb_build_object(
         'income',  coalesce((
           select jsonb_agg(v order by ord)
           from jsonb_array_elements_text(coalesce(cd.data#>'{categories,income}', '[]'::jsonb))
                with ordinality as t(v, ord)
           where v not like '%KMH GELİRİ%'
             and v not like '%KMH ÖDEMESİ%'
             and v not like '%KMH BORCU%'
             and v not like '%KREDİ KARTI ÖDEMESİ%'
         ), '[]'::jsonb),
         'expense', coalesce((
           select jsonb_agg(v order by ord)
           from jsonb_array_elements_text(coalesce(cd.data#>'{categories,expense}', '[]'::jsonb))
                with ordinality as t(v, ord)
           where v not like '%KMH GELİRİ%'
             and v not like '%KMH ÖDEMESİ%'
             and v not like '%KMH BORCU%'
             and v not like '%KREDİ KARTI ÖDEMESİ%'
         ), '[]'::jsonb),
         'fixed',   coalesce((
           select jsonb_agg(v order by ord)
           from jsonb_array_elements_text(coalesce(cd.data#>'{categories,fixed}', '[]'::jsonb))
                with ordinality as t(v, ord)
           where v not like '%KMH GELİRİ%'
             and v not like '%KMH ÖDEMESİ%'
             and v not like '%KMH BORCU%'
             and v not like '%KREDİ KARTI ÖDEMESİ%'
         ), '[]'::jsonb)
       )
     ),
    updated_at = now();

commit;

-- ---------------------------------------------------------------------------
-- 4) Sonuç kontrolü — hepsi 0 olmalı, tanım sayıları korunmuş olmalı
-- ---------------------------------------------------------------------------
select c.name as firma,
       jsonb_array_length(cd.data->'income')                as gelir,
       jsonb_array_length(cd.data->'expense')               as gider,
       jsonb_array_length(cd.data->'fixed')                 as sabit_kesin,
       jsonb_array_length(cd.data->'forecast')              as tahmin,
       jsonb_array_length(cd.data#>'{banking,reversals}')   as ters_kayit,
       jsonb_array_length(cd.data#>'{banking,banks}')       as banka_tanimi,
       jsonb_array_length(cd.data#>'{banking,accounts}')    as hesap_tanimi,
       jsonb_array_length(cd.data#>'{banking,overdrafts}')  as kmh_tanimi,
       jsonb_array_length(cd.data->'creditCards')           as kart_tanimi
from public.company_data cd
join public.companies c on c.id = cd.company_id
order by c.name;

-- ===========================================================================
-- GERİ ALMA (yalnız gerekirse)
-- ---------------------------------------------------------------------------
-- Sıfırlamadan önceki hâle dönmek isterseniz, önce yedeği bulun:
--
--   select id, company_id, backup_name, created_at
--   from public.company_backups
--   where backup_name like 'v0.8.3 sifirlama oncesi%'
--   order by created_at desc;
--
-- Sonra ilgili firmayı geri yükleyin (BACKUP_ID yerine yukarıdaki id):
--
--   update public.company_data cd
--   set data = b.data, updated_at = now()
--   from public.company_backups b
--   where b.id = 'BACKUP_ID' and cd.company_id = b.company_id;
--
-- Tetikleyici normalize tabloları da otomatik geri alır.
-- ===========================================================================
