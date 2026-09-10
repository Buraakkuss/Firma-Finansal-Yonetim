-- NakitPilot v0.7.4
-- Supabase digest() / pgcrypto erişim düzeltmesi
-- Bu kodu Supabase > SQL Editor > New query alanında bir kez çalıştırın.

begin;

-- Supabase uzantılarının standart şeması.
create schema if not exists extensions;

-- pgcrypto daha önce kurulmadıysa kurulur; kuruluysa kayıtlar etkilenmez.
create extension if not exists pgcrypto with schema extensions;

-- Banka/kart/KMH ödeme dağılımlarını senkronize eden fonksiyonun
-- extensions.digest() fonksiyonunu görebilmesini sağlar.
alter function public.np_sync_company_banking_snapshot(uuid, jsonb)
  set search_path = public, extensions;

commit;

-- Kontrol: Aşağıdaki sorgu tek satır SHA-256 değeri döndürmelidir.
select encode(extensions.digest('NakitPilot digest testi'::text, 'sha256'::text), 'hex') as digest_testi;
