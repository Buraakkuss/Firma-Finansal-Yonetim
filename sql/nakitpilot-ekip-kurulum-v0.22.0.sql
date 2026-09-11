-- ============================================================================
-- NakitPilot v0.22.0 — EKİP YÖNETİMİ YENİDEN KURULUM
-- ----------------------------------------------------------------------------
-- Yeni model: kullanıcı kendi kendine kayıt olamaz, davet yoktur, onay yoktur.
-- Yönetici, uygulamadaki Firma & Ekip ekranından e-posta + şifre girer,
-- kullanıcı anında oluşur ve ekibe eklenir. Yönetici bu bilgileri kişiye verir,
-- kişi doğrudan giriş yapar. Şifre unutulursa yönetici yeni şifre belirler;
-- hiçbir aşamada e-posta gönderimi gerekmez.
--
-- TEK PARÇA çalıştırın: Supabase > SQL Editor > yapıştır > Run.
-- Birden çok kez çalıştırılabilir. Mevcut firma/veri/kullanıcılar korunur.
--
-- !!! AŞAĞIDA 2. BÖLÜMDE KENDİ service_role ANAHTARINIZI YAPIŞTIRMANIZ GEREKİR.
-- ============================================================================

-- ── 1) Eski üyelik talebi / davet akışının kaldırılması
DROP FUNCTION IF EXISTS public.np_list_join_requests(uuid);
DROP FUNCTION IF EXISTS public.np_approve_join_request(uuid,uuid,text);
DROP FUNCTION IF EXISTS public.np_reject_join_request(uuid,uuid,text);
DROP FUNCTION IF EXISTS public.np_request_join(uuid,text,text,text,text);
DROP FUNCTION IF EXISTS public.np_my_join_requests();
DROP FUNCTION IF EXISTS public.np_cancel_my_join_request(uuid);
DROP FUNCTION IF EXISTS public.np_list_open_companies();
DROP FUNCTION IF EXISTS public.np_set_join_requests_open(uuid,boolean);
DROP FUNCTION IF EXISTS public.np_pending_join_count(uuid);
DROP FUNCTION IF EXISTS public.np_invite_info(text);
DROP FUNCTION IF EXISTS public.np_claim_invitation(text);
DROP TABLE IF EXISTS public.join_requests;
-- Bekleyen davetler artık kullanılmıyor; kapatılır (tablo durur, veri silinmez).
UPDATE public.company_invitations SET status = 'cancelled' WHERE status = 'pending';

-- ── 2) Yönetici anahtarı  >>> BURAYI DOLDURUN <<<
--
--    service_role anahtarını şuradan alın:
--      Supabase > Project Settings > API Keys > service_role (Reveal)
--    Aşağıdaki 'BURAYA_SERVICE_ROLE_ANAHTARINIZI_YAPISTIRIN' yazan yeri
--    tırnakların arasını bozmadan değiştirin.
--
--    Bu anahtar VERİTABANINDA, RLS ile kapalı bir tabloda durur; tarayıcıya
--    veya uygulamaya asla gönderilmez. Sadece aşağıdaki güvenlik tanımlı
--    (SECURITY DEFINER) fonksiyonlar okuyabilir.
--    ÖNEMLİ: Bu SQL'i anahtarı doldurduktan sonra kimseyle paylaşmayın.

CREATE TABLE IF NOT EXISTS public.np_admin_config (
  key text PRIMARY KEY,
  value text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.np_admin_config ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.np_admin_config FROM anon, authenticated;

INSERT INTO public.np_admin_config(key, value) VALUES
  ('project_url', 'https://ekpehcfhhldtxsuqiczj.supabase.co')
ON CONFLICT (key) DO UPDATE SET value = excluded.value, updated_at = now();

-- Anahtar YALNIZ aşağıdaki tek satırda yazılır. Bu dosyayı tekrar
-- çalıştırırsanız (satırı doldurmadan bile) daha önce girdiğiniz anahtar
-- KORUNUR; üstüne yazılmaz.
DO $kurulum$
DECLARE v_key text := 'BURAYA_SERVICE_ROLE_ANAHTARINIZI_YAPISTIRIN';
BEGIN
  INSERT INTO public.np_admin_config(key, value)
  VALUES ('service_role_key', '(henuz girilmedi)')
  ON CONFLICT (key) DO NOTHING;

  IF v_key NOT LIKE 'BURAYA%' AND length(v_key) > 20 THEN
    UPDATE public.np_admin_config
       SET value = v_key, updated_at = now()
     WHERE key = 'service_role_key';
    RAISE NOTICE 'service_role anahtari kaydedildi.';
  ELSE
    RAISE NOTICE 'Anahtar satiri doldurulmadi; mevcut anahtar korundu.';
  END IF;
END
$kurulum$;

-- Anahtarın girilip girilmediğini tek yerden söyleyen yardımcı.
CREATE OR REPLACE FUNCTION public.np_admin_key()
RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT CASE WHEN value IS NOT NULL AND length(value) > 20
                   AND value NOT LIKE 'BURAYA%' AND value <> '(henuz girilmedi)'
              THEN value ELSE NULL END
  FROM public.np_admin_config WHERE key = 'service_role_key';
$$;
REVOKE ALL ON FUNCTION public.np_admin_key() FROM anon, authenticated;

-- ── 3) HTTP eklentisi (Supabase admin servisine istek atmak için)
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;

-- ── 4) Supabase admin servisine istek atan yardımcı
CREATE OR REPLACE FUNCTION public.np_admin_api(p_method text, p_path text, p_body jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE v_url text; v_key text; v_status int; v_content text;
BEGIN
  SELECT value INTO v_url FROM public.np_admin_config WHERE key = 'project_url';
  v_key := public.np_admin_key();
  IF v_url IS NULL OR v_key IS NULL THEN
    RAISE EXCEPTION 'Yonetici anahtari tanimlanmamis. Kurulum SQL dosyasindaki service_role alanini doldurun.';
  END IF;
  SELECT r.status, r.content INTO v_status, v_content
  FROM extensions.http((
    p_method,
    rtrim(v_url,'/') || p_path,
    ARRAY[
      extensions.http_header('apikey', v_key),
      extensions.http_header('Authorization', 'Bearer ' || v_key)
    ],
    'application/json',
    coalesce(p_body::text, '{}')
  )::extensions.http_request) AS r;
  RETURN jsonb_build_object('status', v_status, 'body',
    CASE WHEN v_content IS NULL OR v_content = '' THEN '{}'::jsonb
         ELSE v_content::jsonb END);
EXCEPTION WHEN others THEN
  RETURN jsonb_build_object('status', 0, 'body', jsonb_build_object('msg', SQLERRM));
END; $$;

-- Hata gövdesinden okunabilir mesaj çıkarır.
CREATE OR REPLACE FUNCTION public.np_admin_api_error(p_body jsonb)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(p_body->>'msg', p_body->>'message', p_body->>'error_description',
                  p_body->>'error', p_body::text);
$$;

-- ── 5) Yönetici yeni kullanıcı oluşturur ve ekibe ekler
CREATE OR REPLACE FUNCTION public.np_create_member(
  p_company_id uuid, p_email text, p_password text, p_full_name text, p_role text)
RETURNS TABLE(member_user_id uuid, member_email text, member_role text,
              was_created boolean, info text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_email text; v_role text; v_uid uuid; v_res jsonb; v_yeni boolean := true; v_not text;
BEGIN
  IF coalesce(public.np_user_role(p_company_id),'') <> 'admin' THEN
    RAISE EXCEPTION 'Kullanici olusturmak icin yonetici yetkisi gerekir.';
  END IF;
  v_email := lower(trim(coalesce(p_email,'')));
  IF v_email = '' OR position('@' in v_email) < 2 THEN
    RAISE EXCEPTION 'Gecerli bir e-posta adresi girin.';
  END IF;
  v_role := public.np_valid_role(p_role);

  SELECT u.id INTO v_uid FROM auth.users u WHERE lower(u.email) = v_email;

  IF v_uid IS NULL THEN
    IF length(coalesce(p_password,'')) < 6 THEN
      RAISE EXCEPTION 'Sifre en az 6 karakter olmalidir.';
    END IF;
    v_res := public.np_admin_api('POST', '/auth/v1/admin/users', jsonb_build_object(
      'email', v_email,
      'password', p_password,
      'email_confirm', true,
      'user_metadata', jsonb_build_object('full_name', nullif(trim(coalesce(p_full_name,'')),''))
    ));
    IF (v_res->>'status')::int NOT IN (200,201) THEN
      RAISE EXCEPTION 'Kullanici olusturulamadi: %', public.np_admin_api_error(v_res->'body');
    END IF;
    v_uid := ((v_res->'body')->>'id')::uuid;
    IF v_uid IS NULL THEN
      RAISE EXCEPTION 'Kullanici olusturuldu ama kimligi okunamadi.';
    END IF;
    v_not := 'Kullanici olusturuldu ve ekibe eklendi.';
  ELSE
    v_yeni := false;
    v_not := 'Bu e-posta ile bir hesap zaten vardi; ekibe eklendi. Sifresi degismedi.';
  END IF;

  INSERT INTO public.company_members(company_id, user_id, role, status)
  VALUES (p_company_id, v_uid, v_role, 'active')
  ON CONFLICT (company_id, user_id)
  DO UPDATE SET role = excluded.role, status = 'active', updated_at = now();

  RETURN QUERY SELECT v_uid, v_email, v_role, v_yeni, v_not;
END; $$;

-- ── 6) Yönetici mevcut üyenin şifresini değiştirir (mail gerekmez)
CREATE OR REPLACE FUNCTION public.np_set_member_password(
  p_company_id uuid, p_member_user_id uuid, p_password text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_res jsonb; v_mail text;
BEGIN
  IF coalesce(public.np_user_role(p_company_id),'') <> 'admin' THEN
    RAISE EXCEPTION 'Sifre belirlemek icin yonetici yetkisi gerekir.';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.company_members cm
                 WHERE cm.company_id = p_company_id AND cm.user_id = p_member_user_id) THEN
    RAISE EXCEPTION 'Bu kullanici firmanin uyesi degil.';
  END IF;
  IF length(coalesce(p_password,'')) < 6 THEN
    RAISE EXCEPTION 'Sifre en az 6 karakter olmalidir.';
  END IF;
  SELECT u.email INTO v_mail FROM auth.users u WHERE u.id = p_member_user_id;
  v_res := public.np_admin_api('PUT', '/auth/v1/admin/users/' || p_member_user_id::text,
                               jsonb_build_object('password', p_password, 'email_confirm', true));
  IF (v_res->>'status')::int NOT IN (200,201) THEN
    RAISE EXCEPTION 'Sifre degistirilemedi: %', public.np_admin_api_error(v_res->'body');
  END IF;
  RETURN coalesce(v_mail,'') ;
END; $$;

-- ── 6b) Ekip listesi: auth.users.email alanı varchar olduğu için açıkça text'e
--      çevrilir (aksi halde "structure of query does not match function result
--      type" hatası çıkabiliyor).
CREATE OR REPLACE FUNCTION public.np_get_team(p_company_id uuid)
RETURNS TABLE(row_type text, row_id uuid, user_id uuid, email text, role text, status text,
              is_owner boolean, is_current_user boolean, created_at timestamptz,
              expires_at timestamptz, invitation_token text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF coalesce(public.np_user_role(p_company_id),'') <> 'admin' THEN
    RAISE EXCEPTION 'Ekip listesi icin yonetici yetkisi gerekir.';
  END IF;
  RETURN QUERY
  SELECT 'member'::text, cm.user_id, cm.user_id, coalesce(u.email,'')::text,
         cm.role::text, cm.status::text, (c.owner_id = cm.user_id),
         (cm.user_id = auth.uid()), cm.created_at, NULL::timestamptz, NULL::text
  FROM public.company_members cm
  JOIN public.companies c ON c.id = cm.company_id
  LEFT JOIN auth.users u ON u.id = cm.user_id
  WHERE cm.company_id = p_company_id
  ORDER BY cm.created_at ASC;
END; $$;
GRANT EXECUTE ON FUNCTION public.np_get_team(uuid) TO authenticated;

-- ── 7) Kurulumun hazır olup olmadığını uygulamaya bildirir
CREATE OR REPLACE FUNCTION public.np_admin_setup_ready()
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN false; END IF;
  RETURN public.np_admin_key() IS NOT NULL;
END; $$;

-- ── 8) Yetkiler
GRANT EXECUTE ON FUNCTION public.np_create_member(uuid,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.np_set_member_password(uuid,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.np_admin_setup_ready() TO authenticated;
REVOKE ALL ON FUNCTION public.np_admin_api(text,text,jsonb) FROM anon, authenticated;

-- ── 9) API şema önbelleğini tazele (yeni fonksiyonlar hemen görünsün)
NOTIFY pgrst, 'reload schema';

-- ── 9b) Kontrol
SELECT 'ayar tablosu' AS kontrol, to_regclass('public.np_admin_config') IS NOT NULL AS tamam
UNION ALL
SELECT 'http eklentisi', EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'http')
UNION ALL
SELECT 'service_role anahtari girildi', public.np_admin_key() IS NOT NULL
UNION ALL
SELECT 'kullanici olusturma fonksiyonu',
       to_regprocedure('public.np_create_member(uuid,text,text,text,text)') IS NOT NULL
UNION ALL
SELECT 'sifre belirleme fonksiyonu',
       to_regprocedure('public.np_set_member_password(uuid,uuid,text)') IS NOT NULL
UNION ALL
SELECT 'eski uyelik talebi tablosu kaldirildi', to_regclass('public.join_requests') IS NULL;
