-- ============================================================================
-- NakitPilot v0.21.0 — Üyelik onayı + davet ile kayıt (TEK PARÇA, KÜMÜLATİF)
-- ----------------------------------------------------------------------------
-- Supabase > SQL Editor'e yapıştırıp Run deyin.
-- Bu dosya v0.20.0 kurulumunu DA içerir: v0.20 dosyasını daha önce
-- çalıştırdıysanız da çalıştırmadıysanız da tek başına yeterlidir.
-- Mevcut veriye dokunmaz; birden çok kez çalıştırılabilir.
--
-- AKIŞ
--   Yönetici davet oluşturur → kişi bağlantıyı açar → ekran doğrudan KAYIT OL
--   formunu açar, davet edilen e-posta kilitli gelir → kişi şifresini belirleyip
--   kayıt olur → sistem otomatik olarak firmaya üyelik talebi açar →
--   yönetici Firma & Ekip ekranından onaylar → kişi giriş yapar.
--   Davet edilmeyen bir e-posta ile kayıt olmaya çalışırsa sistem eşleşmediğini
--   söyler. Davetsiz kayıt olanlar da talep gönderip onay bekleyebilir.
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
DROP FUNCTION IF EXISTS public.np_list_join_requests(uuid);
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
         du.email::text, jr.decision_note
  FROM public.join_requests jr
  LEFT JOIN auth.users du ON du.id = jr.decided_by
  WHERE jr.company_id = p_company_id
  ORDER BY (jr.status = 'pending') DESC, jr.created_at DESC
  LIMIT 200;
END; $$;

-- Yönetici talebi onaylar: kullanıcı seçilen rolle firmaya üye olur.
DROP FUNCTION IF EXISTS public.np_approve_join_request(uuid,uuid,text);
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

-- ── 7) Üyelik talebi hangi davetten geldi
ALTER TABLE public.join_requests
  ADD COLUMN IF NOT EXISTS invitation_id uuid
  REFERENCES public.company_invitations(id) ON DELETE SET NULL;

-- ── 8) Davet bilgisi: bağlantıyı açan kişi henüz giriş yapmamış olabilir.
--    Jetonun kendisi gizli anahtardır; yalnız o jetona sahip olan görür.
CREATE OR REPLACE FUNCTION public.np_invite_info(p_token text)
RETURNS TABLE(company_id uuid, company_name text, invited_email text, invited_role text,
              expires_at timestamptz, is_valid boolean, reason text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_inv public.company_invitations%rowtype; v_name text;
BEGIN
  SELECT * INTO v_inv FROM public.company_invitations ci
   WHERE ci.token = trim(coalesce(p_token,''));
  IF NOT FOUND THEN
    RETURN QUERY SELECT NULL::uuid, NULL::text, NULL::text, NULL::text, NULL::timestamptz,
                        false, 'Davet bulunamadi'::text;
    RETURN;
  END IF;
  SELECT c.name INTO v_name FROM public.companies c WHERE c.id = v_inv.company_id;
  IF v_inv.status = 'accepted' THEN
    RETURN QUERY SELECT v_inv.company_id, v_name, v_inv.email, v_inv.role, v_inv.expires_at,
                        false, 'Davet daha once kullanilmis'::text;
  ELSIF v_inv.status <> 'pending' THEN
    RETURN QUERY SELECT v_inv.company_id, v_name, v_inv.email, v_inv.role, v_inv.expires_at,
                        false, 'Davet iptal edilmis'::text;
  ELSIF v_inv.expires_at <= now() THEN
    RETURN QUERY SELECT v_inv.company_id, v_name, v_inv.email, v_inv.role, v_inv.expires_at,
                        false, 'Davetin suresi dolmus'::text;
  ELSE
    RETURN QUERY SELECT v_inv.company_id, v_name, v_inv.email, v_inv.role, v_inv.expires_at,
                        true, ''::text;
  END IF;
END; $$;

-- ── 9) Davetli kişi kayıt olduktan sonra daveti kullanır: e-posta eşleşiyorsa
--    firmaya üyelik talebi açılır ve yöneticinin onayına düşer.
CREATE OR REPLACE FUNCTION public.np_claim_invitation(p_token text)
RETURNS TABLE(claim_status text, target_company_id uuid, target_company_name text,
              target_role text, target_request_id uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_inv public.company_invitations%rowtype;
        v_name text; v_email text; v_id uuid; v_existing uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Giris gerekli.'; END IF;
  SELECT * INTO v_inv FROM public.company_invitations ci
   WHERE ci.token = trim(coalesce(p_token,''));
  IF NOT FOUND THEN RAISE EXCEPTION 'Davet bulunamadi.'; END IF;
  IF v_inv.status = 'cancelled' THEN RAISE EXCEPTION 'Bu davet iptal edilmis.'; END IF;
  IF v_inv.expires_at <= now() THEN RAISE EXCEPTION 'Davetin suresi dolmus. Yoneticinizden yeni davet isteyin.'; END IF;

  SELECT lower(u.email) INTO v_email FROM auth.users u WHERE u.id = auth.uid();
  v_email := coalesce(v_email, lower(coalesce(auth.jwt()->>'email','')));
  IF v_email IS NULL OR v_email = '' THEN RAISE EXCEPTION 'Hesabin e-postasi okunamadi.'; END IF;
  IF v_email <> lower(v_inv.email) THEN
    RAISE EXCEPTION 'Bu e-posta davet edilen adresle eslesmiyor. Davet % adresine gonderildi.', v_inv.email;
  END IF;

  SELECT c.name INTO v_name FROM public.companies c WHERE c.id = v_inv.company_id;

  IF EXISTS(SELECT 1 FROM public.company_members cm
             WHERE cm.company_id = v_inv.company_id AND cm.user_id = auth.uid()) THEN
    UPDATE public.company_invitations SET status = 'accepted' WHERE id = v_inv.id;
    RETURN QUERY SELECT 'member'::text, v_inv.company_id, v_name, v_inv.role, NULL::uuid;
    RETURN;
  END IF;

  SELECT jr.id INTO v_existing FROM public.join_requests jr
   WHERE jr.company_id = v_inv.company_id AND jr.user_id = auth.uid() AND jr.status = 'pending';
  IF v_existing IS NOT NULL THEN
    UPDATE public.join_requests
       SET invitation_id = v_inv.id, requested_role = v_inv.role
     WHERE id = v_existing;
    RETURN QUERY SELECT 'pending'::text, v_inv.company_id, v_name, v_inv.role, v_existing;
    RETURN;
  END IF;

  INSERT INTO public.join_requests(company_id, user_id, email, full_name, phone, note,
                                   requested_role, invitation_id)
  VALUES (v_inv.company_id, auth.uid(), v_email,
          nullif(trim(coalesce(auth.jwt()->'user_metadata'->>'full_name','')),''),
          nullif(trim(coalesce(auth.jwt()->'user_metadata'->>'phone','')),''),
          'Davet baglantisi ile kayit oldu', v_inv.role, v_inv.id)
  RETURNING join_requests.id INTO v_id;

  RETURN QUERY SELECT 'pending'::text, v_inv.company_id, v_name, v_inv.role, v_id;
END; $$;

-- ── 10) Talep listesi davet bilgisini de göstersin
-- (çıkış kolonu eklendiği için fonksiyon önce düşürülür)
DROP FUNCTION IF EXISTS public.np_list_join_requests(uuid);
CREATE OR REPLACE FUNCTION public.np_list_join_requests(p_company_id uuid)
RETURNS TABLE(id uuid, user_id uuid, email text, full_name text, phone text, note text,
              requested_role text, status text, created_at timestamptz,
              decided_at timestamptz, decided_by_email text, decision_note text,
              from_invitation boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF coalesce(public.np_user_role(p_company_id),'') <> 'admin' THEN
    RAISE EXCEPTION 'Uyelik talepleri icin yonetici yetkisi gerekir.';
  END IF;
  RETURN QUERY
  SELECT jr.id, jr.user_id, jr.email, jr.full_name, jr.phone, jr.note,
         jr.requested_role, jr.status, jr.created_at, jr.decided_at,
         du.email::text, jr.decision_note, (jr.invitation_id IS NOT NULL)
  FROM public.join_requests jr
  LEFT JOIN auth.users du ON du.id = jr.decided_by
  WHERE jr.company_id = p_company_id
  ORDER BY (jr.status = 'pending') DESC, jr.created_at DESC
  LIMIT 200;
END; $$;

-- ── 11) Onay: talep davetten geldiyse davet de "kullanildi" olarak işaretlenir
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

  IF v_req.invitation_id IS NOT NULL THEN
    UPDATE public.company_invitations SET status = 'accepted' WHERE id = v_req.invitation_id;
  END IF;

  RETURN QUERY SELECT v_req.id, v_req.user_id, v_req.email, v_role, 'approved'::text;
END; $$;

-- ── 12) Red: davetten gelen talep reddedilirse davet de iptal edilir
CREATE OR REPLACE FUNCTION public.np_reject_join_request(
  p_company_id uuid, p_request_id uuid, p_note text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_req public.join_requests%rowtype;
BEGIN
  IF coalesce(public.np_user_role(p_company_id),'') <> 'admin' THEN
    RAISE EXCEPTION 'Red icin yonetici yetkisi gerekir.';
  END IF;
  SELECT * INTO v_req FROM public.join_requests jr
   WHERE jr.id = p_request_id AND jr.company_id = p_company_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Talep bulunamadi.'; END IF;
  IF v_req.status <> 'pending' THEN RAISE EXCEPTION 'Bu talep zaten sonuclandirilmis.'; END IF;
  UPDATE public.join_requests
     SET status = 'rejected', decided_by = auth.uid(), decided_at = now(),
         decision_note = nullif(trim(coalesce(p_note,'')),'')
   WHERE id = p_request_id;
  IF v_req.invitation_id IS NOT NULL THEN
    UPDATE public.company_invitations SET status = 'cancelled' WHERE id = v_req.invitation_id;
  END IF;
END; $$;

-- ── 13) Yetkiler — np_invite_info giriş yapmamış kullanıcıya da açıktır
GRANT EXECUTE ON FUNCTION public.np_invite_info(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.np_claim_invitation(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.np_list_join_requests(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.np_approve_join_request(uuid,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.np_reject_join_request(uuid,uuid,text) TO authenticated;


-- ── 14) Kontrol
SELECT 'join_requests tablosu' AS kontrol,
       to_regclass('public.join_requests') IS NOT NULL AS tamam
UNION ALL
SELECT 'allow_join_requests kolonu',
       EXISTS(SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='companies'
                 AND column_name='allow_join_requests')
UNION ALL
SELECT 'invitation_id kolonu',
       EXISTS(SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='join_requests'
                 AND column_name='invitation_id')
UNION ALL
SELECT 'np_invite_info fonksiyonu', to_regprocedure('public.np_invite_info(text)') IS NOT NULL
UNION ALL
SELECT 'np_claim_invitation fonksiyonu', to_regprocedure('public.np_claim_invitation(text)') IS NOT NULL
UNION ALL
SELECT 'roller (5 rol kabul ediliyor)',
       public.np_valid_role('purchasing') = 'purchasing'
         AND public.np_valid_role('engineer') = 'engineer';
