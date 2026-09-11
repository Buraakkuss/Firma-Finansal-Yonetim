-- ============================================================================
-- NakitPilot v0.21.2 — DÜZELTME: "structure of query does not match function
-- result type" hatası (Üyelik Talepleri listesi açılmıyordu)
-- ----------------------------------------------------------------------------
-- Sebep: np_list_join_requests fonksiyonu kararı veren yöneticinin e-postasını
-- auth.users.email alanından okuyor. Supabase'de bu alan varchar(255)'tir,
-- fonksiyon ise text bekliyordu; PostgreSQL tip uyuşmazlığında hata veriyor.
-- Çözüm: alan text'e çevrilerek döndürülüyor.
--
-- TEK PARÇA çalıştırın. Veriye dokunmaz, birden çok kez çalıştırılabilir.
-- (Aynı düzeltme nakitpilot-uyelik-davet-v0.21.0.sql dosyasına da işlendi;
--  o dosyayı yeniden çalıştırmak da aynı sonucu verir.)
-- ============================================================================

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

GRANT EXECUTE ON FUNCTION public.np_list_join_requests(uuid) TO authenticated;

-- Kontrol: hata vermeden çalışmalı (yönetici olduğunuz firmada satır döner).
SELECT 'np_list_join_requests calisiyor' AS kontrol, count(*) AS talep_sayisi
FROM public.np_list_join_requests(
  (SELECT cm.company_id FROM public.company_members cm
    WHERE cm.user_id = auth.uid() AND cm.role = 'admin' LIMIT 1));
