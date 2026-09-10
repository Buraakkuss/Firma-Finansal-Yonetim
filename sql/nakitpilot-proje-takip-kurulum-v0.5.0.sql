-- NakitPilot / Marmara Teknik - Proje Takip modul kurulumu
-- Surum: v0.5.0
-- Kullanim: MT-PRO-Finans Supabase SQL Editor icinde 1 kez calistirin.
-- Amac: Muhendis rolunu ekler, proje modulunun ortak veriyi kaydedebilmesini saglar ve proje dosyalari icin Storage alani acabilir.

-- 1) Rol check constraint'lerini genislet
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.company_members'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%role%'
  LOOP
    EXECUTE format('ALTER TABLE public.company_members DROP CONSTRAINT IF EXISTS %I', r.conname);
  END LOOP;

  ALTER TABLE public.company_members
    ADD CONSTRAINT company_members_role_check
    CHECK (role IN ('admin','accounting','engineer','viewer'));
END $$;

DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.company_invitations'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%role%'
  LOOP
    EXECUTE format('ALTER TABLE public.company_invitations DROP CONSTRAINT IF EXISTS %I', r.conname);
  END LOOP;

  ALTER TABLE public.company_invitations
    ADD CONSTRAINT company_invitations_role_check
    CHECK (role IN ('admin','accounting','engineer','viewer'));
END $$;

-- 2) Ortak veri yazma yetkisi: admin, muhasebe ve muhendis/proje rolu
CREATE OR REPLACE FUNCTION public.np_can_edit_company(p_company_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(public.np_user_role(p_company_id),'') IN ('admin','accounting','engineer');
$$;

-- 3) Firma payload cevabinda can_edit alanini yeni role gore don
CREATE OR REPLACE FUNCTION public.np_company_payload(p_company_id uuid)
RETURNS SETOF public.np_company_payload_row
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    c.id,
    c.name,
    public.np_user_role(c.id),
    c.plan_code,
    c.subscription_status,
    c.trial_ends_at,
    CASE
      WHEN c.trial_ends_at IS NULL THEN NULL::integer
      ELSE greatest(0,ceil(extract(epoch FROM (c.trial_ends_at-now()))/86400.0))::integer
    END,
    true,
    coalesce(public.np_user_role(c.id),'') IN ('admin','accounting','engineer'),
    false,
    coalesce(cd.data,'{}'::jsonb),
    cd.updated_at,
    c.created_at
  FROM public.companies c
  LEFT JOIN public.company_data cd ON cd.company_id = c.id
  WHERE c.id = p_company_id
    AND public.np_is_company_member(c.id);
$$;

-- 4) Davet ve rol degistirme fonksiyonlarinda muhendis rolunu kabul et
CREATE OR REPLACE FUNCTION public.np_invite_member(p_company_id uuid,p_email text,p_role text)
RETURNS TABLE(id uuid, token text, email text, role text, expires_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_token text;
  v_role text;
BEGIN
  IF coalesce(public.np_user_role(p_company_id),'') <> 'admin' THEN
    RAISE EXCEPTION 'Davet icin yonetici yetkisi gerekir.';
  END IF;

  v_role := CASE WHEN p_role IN ('admin','accounting','engineer','viewer') THEN p_role ELSE 'viewer' END;

  INSERT INTO public.company_invitations(company_id,email,role,invited_by)
  VALUES(p_company_id,lower(trim(p_email)),v_role,auth.uid())
  RETURNING company_invitations.id, company_invitations.token INTO v_id, v_token;

  RETURN QUERY
  SELECT ci.id, ci.token, ci.email, ci.role, ci.expires_at
  FROM public.company_invitations ci
  WHERE ci.id = v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.np_update_member_role(p_company_id uuid,p_member_user_id uuid,p_role text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF coalesce(public.np_user_role(p_company_id),'') <> 'admin' THEN
    RAISE EXCEPTION 'Rol degistirme yetkisi yok.';
  END IF;

  UPDATE public.company_members
  SET role = CASE WHEN p_role IN ('admin','accounting','engineer','viewer') THEN p_role ELSE role END,
      updated_at = now()
  WHERE company_id = p_company_id
    AND user_id = p_member_user_id;
END;
$$;

-- 5) Proje dosyalari icin Supabase Storage bucket ve guvenlik politikalari
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('project-files', 'project-files', false, 52428800, NULL)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "project_files_select" ON storage.objects;
DROP POLICY IF EXISTS "project_files_insert" ON storage.objects;
DROP POLICY IF EXISTS "project_files_update" ON storage.objects;
DROP POLICY IF EXISTS "project_files_delete" ON storage.objects;

CREATE POLICY "project_files_select"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'project-files'
  AND public.np_is_company_member(split_part(name,'/',1)::uuid)
);

CREATE POLICY "project_files_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'project-files'
  AND public.np_can_edit_company(split_part(name,'/',1)::uuid)
);

CREATE POLICY "project_files_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'project-files'
  AND public.np_can_edit_company(split_part(name,'/',1)::uuid)
)
WITH CHECK (
  bucket_id = 'project-files'
  AND public.np_can_edit_company(split_part(name,'/',1)::uuid)
);

CREATE POLICY "project_files_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'project-files'
  AND public.np_can_edit_company(split_part(name,'/',1)::uuid)
);

-- 6) Mevcut Marmara Teknik verisine mtpro anahtarini bos olarak ekle; mevcut veriye zarar vermez.
UPDATE public.company_data
SET data = jsonb_set(
      coalesce(data,'{}'::jsonb),
      '{mtpro}',
      coalesce(data->'mtpro', '{"meetings":[],"projects":[],"costs":[],"files":[],"activity":[]}'::jsonb),
      true
    ),
    updated_at = now()
WHERE true;
