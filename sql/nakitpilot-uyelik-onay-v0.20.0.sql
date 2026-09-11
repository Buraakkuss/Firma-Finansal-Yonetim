-- ============================================================================
-- NakitPilot v0.20.0 — Üyelik talebi / yönetici onayı ve davet düzeltmeleri
-- ----------------------------------------------------------------------------
-- Bu dosya TEK PARÇA çalıştırılır. Supabase > SQL Editor'e yapıştırıp Run deyin.
-- Mevcut veriye dokunmaz; yalnız ekler ve düzeltir. İki kez çalıştırılabilir.
--
-- 1) Rol listesi düzeltmesi: davet ve rol değiştirme fonksiyonları 'engineer'
--    ve 'purchasing' rollerini kabul etmiyordu, sessizce 'viewer' yapıyordu.
-- 2) Yeni: üyelik talebi tablosu (join_requests) ve onay akışı.
--    Kullanıcı giriş ekranından kayıt olur, firmaya katılma talebi gönderir,
--    yönetici Firma & Ekip ekranından onaylar; onaylanınca kullanıcı girebilir.
--
-- NOT: sql/ klasöründeki ESKİ kurulum dosyalarını tekrar çalıştırmayın.
-- ============================================================================

-- ── 1) Rol kısıtları: beş rol (admin, accounting, engineer, purchasing, viewer)
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT conname, conrelid::regclass AS tbl
    FROM pg_constraint
    WHERE conrelid IN ('public.company_members'::regclass,'public.company_invitations'::regclass)
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%role%'
  LOOP
    EXECUTE format('ALTER TABLE %s DROP CONSTRAINT IF EXISTS %I', r.tbl, r.conname);
  END LOOP;

  ALTER TABLE public.company_members
    ADD CONSTRAINT company_members_role_check
    CHECK (role IN ('admin','accounting','engineer','purchasing','viewer'));

  ALTER TABLE public.company_invitations
    ADD CONSTRAINT company_invitations_role_check
    CHECK (role IN ('admin','accounting','engineer','purchasing','viewer'));
END $$;

CREATE OR REPLACE FUNCTION public.np_valid_role(p_role text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = public AS $$
  SELECT CASE WHEN lower(coalesce(p_role,'')) IN ('admin','accounting','engineer','purchasing','viewer')
              THEN lower(p_role) ELSE 'viewer' END;
$$;

CREATE OR REPLACE FUNCTION public.np_invite_member(p_company_id uuid, p_email text, p_role text)
RETURNS TABLE(id uuid, token text, email text, role text, expires_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF coalesce(public.np_user_role(p_company_id),'') <> 'admin' THEN
    RAISE EXCEPTION 'Davet icin yonetici yetkisi gerekir.';
  END IF;
  v_email := lower(trim(coalesce(p_email,'')));
  IF v_email = '' OR position('@' in v_email) < 2 THEN
    RAISE EXCEPTION 'Gecerli bir e-posta adresi girin.';
  END IF;
  -- Zaten üye olan biri tekrar davet edilmez.
  IF EXISTS (
    SELECT 1 FROM public.company_members cm
    JOIN auth.users u ON u.id = cm.user_id
    WHERE cm.company_id = p_company_id AND lower(u.email) = v_email
  ) THEN
    RAISE EXCEPTION 'Bu e-posta zaten firmanin uyesi.';
  END IF;
  -- Aynı e-postaya bekleyen davet varsa yenisi açılmaz, mevcut davet tazelenir.
  UPDATE public.company_invitations ci
     SET status = 'cancelled'
   WHERE ci.company_id = p_company_id AND lower(ci.email) = v_email AND ci.status = 'pending';

  INSERT INTO public.company_invitations(company_id, email, role, invited_by)
  VALUES (p_company_id, v_email, public.np_valid_role(p_role), auth.uid())
  RETURNING company_invitations.id INTO v_id;

  RETURN QUERY
    SELECT ci.id, ci.token, ci.email, ci.role, ci.expires_at
    FROM public.company_invitations ci WHERE ci.id = v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.np_update_member_role(p_company_id uuid, p_member_user_id uuid, p_role text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_owner uuid;
BEGIN
  IF coalesce(public.np_user_role(p_company_id),'') <> 'admin' THEN
    RAISE EXCEPTION 'Rol degistirme yetkisi yok.';
  END IF;
  SELECT owner_id INTO v_owner FROM public.companies WHERE id = p_company_id;
  -- Firma sahibinin yönetici yetkisi elinden alınamaz.
  IF p_member_user_id = v_owner AND public.np_valid_role(p_role) <> 'admin' THEN
    RAISE EXCEPTION 'Firma sahibinin yonetici yetkisi kaldirilamaz.';
  END IF;
  UPDATE public.company_members
     SET role = public.np_valid_role(p_role), updated_at = now()
   WHERE company_id = p_company_id AND user_id = p_member_user_id;
END; $$;

-- ── 2) Firmanın üyelik talebine açık olup olmadığı
ALTER TABLE public.companies
  ADD COLUMN IF NOT EXISTS allow_join_requests boolean NOT NULL DEFAULT true;

-- ── 3) Üyelik talepleri tablosu
CREATE TABLE IF NOT EXISTS public.join_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  full_name text,
  phone text,
  note text,
  requested_role text NOT NULL DEFAULT 'viewer'
    CHECK (requested_role IN ('admin','accounting','engineer','purchasing','viewer')),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected','cancelled')),
  decided_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  decided_at timestamptz,
  decision_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS join_requests_one_pending_idx
  ON public.join_requests(company_id, user_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS join_requests_company_idx ON public.join_requests(company_id, status);
CREATE INDEX IF NOT EXISTS join_requests_user_idx ON public.join_requests(user_id);

ALTER TABLE public.join_requests ENABLE ROW LEVEL SECURITY;
-- Tabloya doğrudan erişim yok; yalnız aşağıdaki SECURITY DEFINER fonksiyonlar okur/yazar.
REVOKE ALL ON public.join_requests FROM anon, authenticated;

-- ── 4) Üyelik talebi fonksiyonları
-- Kayıt olan kullanıcının katılabileceği firmalar (yalnız talebe açık olanlar).
CREATE OR REPLACE FUNCTION public.np_list_open_companies()
RETURNS TABLE(company_id uuid, company_name text, already_member boolean, pending_request boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Giris gerekli.'; END IF;
  RETURN QUERY
  SELECT c.id, c.name,
         EXISTS(SELECT 1 FROM public.company_members cm
                 WHERE cm.company_id = c.id AND cm.user_id = auth.uid()),
         EXISTS(SELECT 1 FROM public.join_requests jr
                 WHERE jr.company_id = c.id AND jr.user_id = auth.uid() AND jr.status = 'pending')
  FROM public.companies c
  WHERE coalesce(c.allow_join_requests, true)
  ORDER BY c.name;
END; $$;

-- Kullanıcı bir firmaya katılma talebi gönderir.
CREATE OR REPLACE FUNCTION public.np_request_join(
  p_company_id uuid, p_full_name text, p_phone text, p_note text, p_role text)
RETURNS TABLE(id uuid, company_id uuid, company_name text, status text,
              requested_role text, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid; v_email text; v_open boolean;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Giris gerekli.'; END IF;
  SELECT coalesce(c.allow_join_requests, true) INTO v_open
    FROM public.companies c WHERE c.id = p_company_id;
  IF v_open IS NULL THEN RAISE EXCEPTION 'Firma bulunamadi.'; END IF;
  IF NOT v_open THEN RAISE EXCEPTION 'Bu firma yeni uyelik talebi kabul etmiyor.'; END IF;
  IF EXISTS(SELECT 1 FROM public.company_members cm
             WHERE cm.company_id = p_company_id AND cm.user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Zaten bu firmanin uyesisiniz.';
  END IF;
  IF EXISTS(SELECT 1 FROM public.join_requests jr
             WHERE jr.company_id = p_company_id AND jr.user_id = auth.uid() AND jr.status = 'pending') THEN
    RAISE EXCEPTION 'Bu firma icin zaten bekleyen bir talebiniz var.';
  END IF;
  SELECT lower(u.email) INTO v_email FROM auth.users u WHERE u.id = auth.uid();

  INSERT INTO public.join_requests(company_id, user_id, email, full_name, phone, note, requested_role)
  VALUES (p_company_id, auth.uid(), coalesce(v_email, lower(coalesce(auth.jwt()->>'email',''))),
          nullif(trim(coalesce(p_full_name,'')),''), nullif(trim(coalesce(p_phone,'')),''),
          nullif(trim(coalesce(p_note,'')),''), public.np_valid_role(p_role))
  RETURNING join_requests.id INTO v_id;

  RETURN QUERY
    SELECT jr.id, jr.company_id, c.name, jr.status, jr.requested_role, jr.created_at
    FROM public.join_requests jr JOIN public.companies c ON c.id = jr.company_id
    WHERE jr.id = v_id;
END; $$;

-- Kullanıcının kendi talepleri (bekleyen ve karara bağlanmış).
CREATE OR REPLACE FUNCTION public.np_my_join_requests()
RETURNS TABLE(id uuid, company_id uuid, company_name text, status text, requested_role text,
              decision_note text, created_at timestamptz, decided_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Giris gerekli.'; END IF;
  RETURN QUERY
  SELECT jr.id, jr.company_id, c.name, jr.status, jr.requested_role,
         jr.decision_note, jr.created_at, jr.decided_at
  FROM public.join_requests jr JOIN public.companies c ON c.id = jr.company_id
  WHERE jr.user_id = auth.uid()
  ORDER BY jr.created_at DESC;
END; $$;

-- Kullanıcı kendi bekleyen talebini geri çeker.
CREATE OR REPLACE FUNCTION public.np_cancel_my_join_request(p_request_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Giris gerekli.'; END IF;
  UPDATE public.join_requests
     SET status = 'cancelled', decided_at = now()
   WHERE id = p_request_id AND user_id = auth.uid() AND status = 'pending';
END; $$;

-- Yöneticinin gördüğü talep listesi (bekleyenler önce).
CREATE OR REPLACE FUNCTION public.np_list_join_requests(p_company_id uuid)
RETURNS TABLE(id uuid, user_id uuid, email text, full_name text, phone text, note text,
              requested_role text, status text, created_at timestamptz,
              decided_at timestamptz, decided_by_email text, decision_note text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF coalesce(public.np_user_role(p_company_id),'') <> 'admin' THEN
    RAISE EXCEPTION 'Uyelik talepleri icin yonetici yetkisi gerekir.';
  END IF;
  RETURN QUERY
  SELECT jr.id, jr.user_id, jr.email, jr.full_name, jr.phone, jr.note,
         jr.requested_role, jr.status, jr.created_at, jr.decided_at,
         du.email, jr.decision_note
  FROM public.join_requests jr
  LEFT JOIN auth.users du ON du.id = jr.decided_by
  WHERE jr.company_id = p_company_id
  ORDER BY (jr.status = 'pending') DESC, jr.created_at DESC
  LIMIT 200;
END; $$;

-- Yönetici talebi onaylar: kullanıcı seçilen rolle firmaya üye olur.
CREATE OR REPLACE FUNCTION public.np_approve_join_request(
  p_company_id uuid, p_request_id uuid, p_role text)
RETURNS TABLE(request_id uuid, member_user_id uuid, member_email text, member_role text, new_status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_req public.join_requests%rowtype; v_role text;
BEGIN
  IF coalesce(public.np_user_role(p_company_id),'') <> 'admin' THEN
    RAISE EXCEPTION 'Onay icin yonetici yetkisi gerekir.';
  END IF;
  SELECT * INTO v_req FROM public.join_requests
   WHERE join_requests.id = p_request_id AND join_requests.company_id = p_company_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Talep bulunamadi.'; END IF;
  IF v_req.status <> 'pending' THEN RAISE EXCEPTION 'Bu talep zaten sonuclandirilmis.'; END IF;

  v_role := public.np_valid_role(coalesce(nullif(trim(coalesce(p_role,'')),''), v_req.requested_role));

  INSERT INTO public.company_members(company_id, user_id, role, status)
  VALUES (p_company_id, v_req.user_id, v_role, 'active')
  ON CONFLICT (company_id, user_id)
  DO UPDATE SET role = excluded.role, status = 'active', updated_at = now();

  UPDATE public.join_requests
     SET status = 'approved', decided_by = auth.uid(), decided_at = now(),
         requested_role = v_role
   WHERE join_requests.id = p_request_id;

  RETURN QUERY SELECT v_req.id, v_req.user_id, v_req.email, v_role, 'approved'::text;
END; $$;

-- Yönetici talebi reddeder (sebep yazabilir).
CREATE OR REPLACE FUNCTION public.np_reject_join_request(
  p_company_id uuid, p_request_id uuid, p_note text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_status text;
BEGIN
  IF coalesce(public.np_user_role(p_company_id),'') <> 'admin' THEN
    RAISE EXCEPTION 'Red icin yonetici yetkisi gerekir.';
  END IF;
  SELECT jr.status INTO v_status FROM public.join_requests jr
   WHERE jr.id = p_request_id AND jr.company_id = p_company_id;
  IF v_status IS NULL THEN RAISE EXCEPTION 'Talep bulunamadi.'; END IF;
  IF v_status <> 'pending' THEN RAISE EXCEPTION 'Bu talep zaten sonuclandirilmis.'; END IF;
  UPDATE public.join_requests
     SET status = 'rejected', decided_by = auth.uid(), decided_at = now(),
         decision_note = nullif(trim(coalesce(p_note,'')),'')
   WHERE id = p_request_id;
END; $$;

-- Yönetici firmayı üyelik talebine açar/kapatır.
CREATE OR REPLACE FUNCTION public.np_set_join_requests_open(p_company_id uuid, p_open boolean)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF coalesce(public.np_user_role(p_company_id),'') <> 'admin' THEN
    RAISE EXCEPTION 'Bu ayar icin yonetici yetkisi gerekir.';
  END IF;
  UPDATE public.companies SET allow_join_requests = coalesce(p_open, true) WHERE id = p_company_id;
  RETURN coalesce(p_open, true);
END; $$;

-- Yöneticinin bekleyen talep sayısını hızlı okuması için.
CREATE OR REPLACE FUNCTION public.np_pending_join_count(p_company_id uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count integer;
BEGIN
  IF coalesce(public.np_user_role(p_company_id),'') <> 'admin' THEN RETURN 0; END IF;
  SELECT count(*) INTO v_count FROM public.join_requests
   WHERE company_id = p_company_id AND status = 'pending';
  RETURN coalesce(v_count,0);
END; $$;

-- ── 5) Yetkiler
GRANT EXECUTE ON FUNCTION public.np_valid_role(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.np_invite_member(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.np_update_member_role(uuid,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.np_list_open_companies() TO authenticated;
GRANT EXECUTE ON FUNCTION public.np_request_join(uuid,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.np_my_join_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.np_cancel_my_join_request(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.np_list_join_requests(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.np_approve_join_request(uuid,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.np_reject_join_request(uuid,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.np_set_join_requests_open(uuid,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.np_pending_join_count(uuid) TO authenticated;

-- ── 6) Kontrol
SELECT 'join_requests tablosu' AS kontrol,
       to_regclass('public.join_requests') IS NOT NULL AS tamam
UNION ALL
SELECT 'allow_join_requests kolonu',
       EXISTS(SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='companies'
                 AND column_name='allow_join_requests')
UNION ALL
SELECT 'roller (5 rol kabul ediliyor)',
       public.np_valid_role('purchasing') = 'purchasing'
         AND public.np_valid_role('engineer') = 'engineer';
