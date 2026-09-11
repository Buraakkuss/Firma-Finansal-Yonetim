-- ===========================================================================
-- NakitPilot v0.10.0 — "Satın Alma" rolünün eklenmesi
-- ---------------------------------------------------------------------------
-- Supabase > SQL Editor'a tamamını yapıştırıp bir kez Run deyin.
--
-- NE YAPAR
--   company_members ve company_invitations tablolarındaki rol kısıtına
--   'purchasing' değerini ekler. Böylece ekip üyelerine Satın Alma rolü
--   atanabilir.
--
-- GEREKLİ Mİ?
--   Zorunlu değildir. Satın Alma yetkisini, mevcut bir role sahip kullanıcıya
--   uygulama içinden "Firma & Ekip > Modül Yetkileri" ekranından da
--   verebilirsiniz. Bu SQL yalnız ayrı bir rol olarak görünmesini sağlar.
--
-- GÜVENLİ MİDİR?
--   Evet. Yalnız kısıt genişletilir, hiçbir veri silinmez veya değişmez.
--   Mevcut roller aynen çalışmaya devam eder.
-- ===========================================================================

begin;

DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'public.company_members'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%role%'
  LOOP
    EXECUTE format('ALTER TABLE public.company_members DROP CONSTRAINT IF EXISTS %I', r.conname);
  END LOOP;

  ALTER TABLE public.company_members
    ADD CONSTRAINT company_members_role_check
    CHECK (role IN ('admin','accounting','engineer','purchasing','viewer'));
END $$;

DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'public.company_invitations'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%role%'
  LOOP
    EXECUTE format('ALTER TABLE public.company_invitations DROP CONSTRAINT IF EXISTS %I', r.conname);
  END LOOP;

  ALTER TABLE public.company_invitations
    ADD CONSTRAINT company_invitations_role_check
    CHECK (role IN ('admin','accounting','engineer','purchasing','viewer'));
END $$;

-- Satın alma rolü de ortak veriye yazabilmelidir.
CREATE OR REPLACE FUNCTION public.np_can_edit_company(p_company_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.company_members m
    WHERE m.company_id = p_company_id
      AND m.user_id = auth.uid()
      AND m.status = 'active'
      AND m.role IN ('admin','accounting','engineer','purchasing')
  );
$$;

commit;

-- Kontrol: kısıtın güncel hâli
select conname, pg_get_constraintdef(oid) as tanim
from pg_constraint
where conrelid in ('public.company_members'::regclass,'public.company_invitations'::regclass)
  and contype='c' and pg_get_constraintdef(oid) ilike '%role%';
