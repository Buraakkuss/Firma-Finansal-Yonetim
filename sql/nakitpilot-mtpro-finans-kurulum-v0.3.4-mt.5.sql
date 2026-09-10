
-- NakitPilot Marmara Teknik - MT-PRO-Finans Uyumlu Kurulum
-- Surum: v0.3.4-mt.5
-- Tarih: 23.06.2026
-- Kullanim: Bu dosyayi MT-PRO-Finans Supabase projesinde calistirin.
-- Proje ID: ekpehcfhhldtxsuqiczj
-- Amac: https://www.marmarateknikmakine.com.tr/finans-yonetim/ uygulamasinin kullanacagi NakitPilot tablolarini ve RPC fonksiyonlarini kurmak.

create extension if not exists pgcrypto;

-- Temel tablolar
create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid references auth.users(id) on delete set null,
  plan_code text not null default 'internal',
  subscription_status text not null default 'active',
  trial_ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.company_members (
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'viewer' check (role in ('admin','accounting','viewer')),
  status text not null default 'active' check (status in ('active','invited','disabled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(company_id,user_id)
);

create table if not exists public.company_data (
  company_id uuid primary key references public.companies(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

create table if not exists public.company_backups (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  backup_name text not null,
  data jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.company_invitations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  email text not null,
  role text not null default 'viewer' check (role in ('admin','accounting','viewer')),
  token text not null unique default encode(gen_random_bytes(24),'hex'),
  status text not null default 'pending' check (status in ('pending','accepted','cancelled','expired')),
  invited_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '14 days')
);

create table if not exists public.subscription_requests (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  requester_id uuid references auth.users(id) on delete set null,
  requester_email text,
  plan_code text not null,
  note text,
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  created_at timestamptz not null default now(),
  decided_at timestamptz
);

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.companies(id) on delete cascade,
  requester_id uuid references auth.users(id) on delete set null,
  requester_email text,
  type text,
  priority text,
  subject text not null,
  message text not null,
  status text not null default 'open' check (status in ('open','in_progress','closed')),
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.companies(id) on delete cascade,
  requester_id uuid references auth.users(id) on delete set null,
  requester_email text,
  reason text,
  status text not null default 'pending' check (status in ('pending','approved','rejected','completed')),
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.companies(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  user_email text,
  action text not null,
  description text,
  entity_type text,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.settings_change_requests (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  requester_id uuid not null references auth.users(id) on delete cascade,
  requester_email text not null,
  request_type text not null check (request_type in ('email_change','password_change','system_setting','profile_setting')),
  title text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending','approved','rejected','applied')),
  admin_id uuid references auth.users(id) on delete set null,
  admin_email text,
  admin_note text,
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  applied_at timestamptz
);

create index if not exists company_members_user_idx on public.company_members(user_id,status);
create index if not exists company_data_updated_idx on public.company_data(updated_at desc);
create index if not exists company_invitations_token_idx on public.company_invitations(token);
create index if not exists settings_change_requests_company_idx on public.settings_change_requests(company_id, created_at desc);

-- RLS acik, islemler RPC ile yapilir.
alter table public.companies enable row level security;
alter table public.company_members enable row level security;
alter table public.company_data enable row level security;
alter table public.company_backups enable row level security;
alter table public.company_invitations enable row level security;
alter table public.subscription_requests enable row level security;
alter table public.support_tickets enable row level security;
alter table public.account_deletion_requests enable row level security;
alter table public.audit_logs enable row level security;
alter table public.settings_change_requests enable row level security;

create or replace function public.np_is_primary_marmara_admin()
returns boolean language sql stable security definer set search_path=public as $$
  select lower(coalesce(auth.jwt() ->> 'email','')) = 'tburak.kus@marmarateknikmakine.com.tr';
$$;

create or replace function public.np_is_company_active(p_company_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.companies c where c.id=p_company_id);
$$;

create or replace function public.np_user_role(p_company_id uuid)
returns text language sql stable security definer set search_path=public as $$
  select case
    when public.np_is_primary_marmara_admin() and exists(select 1 from public.companies c where c.id=p_company_id) then 'admin'::text
    else (select cm.role from public.company_members cm where cm.company_id=p_company_id and cm.user_id=auth.uid() and cm.status='active' limit 1)
  end;
$$;

create or replace function public.np_is_company_member(p_company_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select (public.np_is_primary_marmara_admin() and exists(select 1 from public.companies c where c.id=p_company_id))
      or exists(select 1 from public.company_members cm where cm.company_id=p_company_id and cm.user_id=auth.uid() and cm.status='active');
$$;

create or replace function public.np_can_edit_company(p_company_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select coalesce(public.np_user_role(p_company_id),'') in ('admin','accounting');
$$;

-- RPC ortak cevap tipi
-- Tekrar calistirmalarda fonksiyon tip bagimliliklarini temizlemek icin cascade kullanilir; asagida tum fonksiyonlar yeniden kurulur.
drop type if exists public.np_company_payload_row cascade;
create type public.np_company_payload_row as (
  company_id uuid,
  company_name text,
  user_role text,
  plan_code text,
  subscription_status text,
  trial_ends_at timestamptz,
  trial_days_left integer,
  is_active boolean,
  can_edit boolean,
  billing_required boolean,
  app_data jsonb,
  updated_at timestamptz,
  created_at timestamptz
);


create or replace function public.np_company_payload(p_company_id uuid)
returns setof public.np_company_payload_row
language sql stable security definer set search_path=public as $$
  select c.id, c.name, public.np_user_role(c.id), c.plan_code, c.subscription_status, c.trial_ends_at,
    case when c.trial_ends_at is null then null::integer else greatest(0,ceil(extract(epoch from (c.trial_ends_at-now()))/86400.0))::integer end,
    true, coalesce(public.np_user_role(c.id),'') in ('admin','accounting'), false,
    coalesce(cd.data,'{}'::jsonb), coalesce(cd.updated_at,c.updated_at), c.created_at
  from public.companies c
  left join public.company_data cd on cd.company_id=c.id
  where c.id=p_company_id and public.np_is_company_member(c.id);
$$;

create or replace function public.np_get_my_companies()
returns table(company_id uuid, company_name text, user_role text, plan_code text, subscription_status text, trial_ends_at timestamptz, trial_days_left integer, is_active boolean, created_at timestamptz)
language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'Giris gerekli.'; end if;
  if public.np_is_primary_marmara_admin() then
    return query select c.id,c.name,'admin'::text,c.plan_code,c.subscription_status,c.trial_ends_at,null::integer,true,c.created_at from public.companies c order by c.created_at asc;
  else
    return query select c.id,c.name,cm.role,c.plan_code,c.subscription_status,c.trial_ends_at,
      case when c.trial_ends_at is null then null::integer else greatest(0,ceil(extract(epoch from (c.trial_ends_at-now()))/86400.0))::integer end,
      true,c.created_at
    from public.companies c join public.company_members cm on cm.company_id=c.id
    where cm.user_id=auth.uid() and cm.status='active' order by c.created_at asc;
  end if;
end; $$;

create or replace function public.np_create_company(p_company_name text)
returns setof public.np_company_payload_row language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_name text; begin
  if auth.uid() is null then raise exception 'Giris gerekli.'; end if;
  v_name := left(coalesce(nullif(trim(p_company_name),''),'Yeni Firma'),160);
  insert into public.companies(name,owner_id,plan_code,subscription_status) values(v_name,auth.uid(),'internal','active') returning id into v_id;
  insert into public.company_members(company_id,user_id,role,status) values(v_id,auth.uid(),'admin','active') on conflict(company_id,user_id) do update set role='admin',status='active',updated_at=now();
  insert into public.company_data(company_id,data,updated_by) values(v_id,'{}'::jsonb,auth.uid()) on conflict(company_id) do nothing;
  return query select * from public.np_company_payload(v_id);
end; $$;

create or replace function public.np_get_company_data(p_company_id uuid)
returns setof public.np_company_payload_row language sql stable security definer set search_path=public as $$
  select * from public.np_company_payload(p_company_id);
$$;

create or replace function public.np_save_company_data(p_company_id uuid,p_data jsonb)
returns setof public.np_company_payload_row language plpgsql security definer set search_path=public as $$
begin
  if coalesce(public.np_user_role(p_company_id),'') <> 'admin' then raise exception 'Bu islem icin yonetici yetkisi gerekir.'; end if;
  insert into public.company_data(company_id,data,updated_at,updated_by) values(p_company_id,coalesce(p_data,'{}'::jsonb),now(),auth.uid())
  on conflict(company_id) do update set data=excluded.data,updated_at=now(),updated_by=auth.uid();
  update public.companies set updated_at=now() where id=p_company_id;
  return query select * from public.np_company_payload(p_company_id);
end; $$;

create or replace function public.np_add_daily_record(p_company_id uuid,p_kind text,p_record jsonb)
returns setof public.np_company_payload_row language plpgsql security definer set search_path=public as $$
declare v_data jsonb; v_key text; v_arr jsonb; begin
  if not public.np_can_edit_company(p_company_id) then raise exception 'Gelir/gider ekleme yetkiniz yok.'; end if;
  v_key := case when p_kind='income' then 'income' when p_kind='expense' then 'expense' else null end;
  if v_key is null then raise exception 'Gecersiz kayit turu.'; end if;
  select coalesce(data,'{}'::jsonb) into v_data from public.company_data where company_id=p_company_id for update;
  if v_data is null then v_data:='{}'::jsonb; end if;
  v_arr := coalesce(v_data->v_key,'[]'::jsonb) || jsonb_build_array(coalesce(p_record,'{}'::jsonb));
  v_data := jsonb_set(v_data, array[v_key], v_arr, true);
  insert into public.company_data(company_id,data,updated_at,updated_by) values(p_company_id,v_data,now(),auth.uid())
  on conflict(company_id) do update set data=excluded.data,updated_at=now(),updated_by=auth.uid();
  return query select * from public.np_company_payload(p_company_id);
end; $$;

create or replace function public.np_update_daily_record_link(p_company_id uuid,p_kind text,p_record_id text,p_fixed_link_id text,p_fixed_link_month text,p_fixed_link_close_mode text)
returns setof public.np_company_payload_row language plpgsql security definer set search_path=public as $$
declare v_data jsonb; v_key text; v_arr jsonb; v_new jsonb='[]'::jsonb; item jsonb; begin
  if not public.np_can_edit_company(p_company_id) then raise exception 'Iliskilendirme yetkiniz yok.'; end if;
  v_key := case when p_kind='income' then 'income' else 'expense' end;
  select coalesce(data,'{}'::jsonb) into v_data from public.company_data where company_id=p_company_id for update;
  v_arr := coalesce(v_data->v_key,'[]'::jsonb);
  for item in select * from jsonb_array_elements(v_arr) loop
    if coalesce(item->>'id','')=coalesce(p_record_id,'') then
      item := item || jsonb_build_object('fixedLinkId',p_fixed_link_id,'fixedLinkMonth',p_fixed_link_month,'fixedLinkCloseMode',coalesce(p_fixed_link_close_mode,'partial'));
    end if;
    v_new := v_new || jsonb_build_array(item);
  end loop;
  v_data := jsonb_set(v_data,array[v_key],v_new,true);
  update public.company_data set data=v_data,updated_at=now(),updated_by=auth.uid() where company_id=p_company_id;
  return query select * from public.np_company_payload(p_company_id);
end; $$;

create or replace function public.np_create_company_backup(p_company_id uuid,p_backup_name text,p_data jsonb)
returns void language plpgsql security definer set search_path=public as $$
begin
  if coalesce(public.np_user_role(p_company_id),'') <> 'admin' then raise exception 'Yedek icin yonetici yetkisi gerekir.'; end if;
  insert into public.company_backups(company_id,backup_name,data,created_by) values(p_company_id,left(coalesce(p_backup_name,'Yedek'),180),coalesce(p_data,'{}'::jsonb),auth.uid());
end; $$;

create or replace function public.np_invite_member(p_company_id uuid,p_email text,p_role text)
returns table(id uuid, token text, email text, role text, expires_at timestamptz)
language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_token text; begin
  if coalesce(public.np_user_role(p_company_id),'') <> 'admin' then raise exception 'Davet icin yonetici yetkisi gerekir.'; end if;
  insert into public.company_invitations(company_id,email,role,invited_by) values(p_company_id,lower(trim(p_email)),case when p_role in ('admin','accounting','viewer') then p_role else 'viewer' end,auth.uid()) returning company_invitations.id,company_invitations.token into v_id,v_token;
  return query select ci.id,ci.token,ci.email,ci.role,ci.expires_at from public.company_invitations ci where ci.id=v_id;
end; $$;

create or replace function public.np_accept_invitation(p_token text)
returns setof public.np_company_payload_row language plpgsql security definer set search_path=public as $$
declare v_inv public.company_invitations%rowtype; begin
  if auth.uid() is null then raise exception 'Giris gerekli.'; end if;
  select * into v_inv from public.company_invitations where token=p_token and status='pending' and expires_at>now();
  if not found then raise exception 'Gecerli davet bulunamadi.'; end if;
  insert into public.company_members(company_id,user_id,role,status) values(v_inv.company_id,auth.uid(),v_inv.role,'active') on conflict(company_id,user_id) do update set role=excluded.role,status='active',updated_at=now();
  update public.company_invitations set status='accepted' where id=v_inv.id;
  return query select * from public.np_company_payload(v_inv.company_id);
end; $$;

create or replace function public.np_get_team(p_company_id uuid)
returns table(row_type text,row_id uuid,user_id uuid,email text,role text,status text,is_owner boolean,is_current_user boolean,created_at timestamptz,expires_at timestamptz,invitation_token text)
language plpgsql security definer set search_path=public as $$
begin
  if coalesce(public.np_user_role(p_company_id),'') <> 'admin' then raise exception 'Ekip listesi icin yonetici yetkisi gerekir.'; end if;
  return query
  select 'member'::text, cm.user_id, cm.user_id, coalesce(u.email,''), cm.role, cm.status, (c.owner_id=cm.user_id), (cm.user_id=auth.uid()), cm.created_at, null::timestamptz, null::text
  from public.company_members cm join public.companies c on c.id=cm.company_id left join auth.users u on u.id=cm.user_id
  where cm.company_id=p_company_id
  union all
  select 'invitation'::text, ci.id, null::uuid, ci.email, ci.role, ci.status, false, false, ci.created_at, ci.expires_at, ci.token
  from public.company_invitations ci where ci.company_id=p_company_id and ci.status='pending'
  order by created_at asc;
end; $$;

create or replace function public.np_update_member_role(p_company_id uuid,p_member_user_id uuid,p_role text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if coalesce(public.np_user_role(p_company_id),'') <> 'admin' then raise exception 'Rol degistirme yetkisi yok.'; end if;
  update public.company_members set role=case when p_role in ('admin','accounting','viewer') then p_role else role end,updated_at=now() where company_id=p_company_id and user_id=p_member_user_id;
end; $$;

create or replace function public.np_remove_member(p_company_id uuid,p_member_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if coalesce(public.np_user_role(p_company_id),'') <> 'admin' then raise exception 'Kullanici cikarma yetkisi yok.'; end if;
  delete from public.company_members where company_id=p_company_id and user_id=p_member_user_id and user_id<>auth.uid();
end; $$;

create or replace function public.np_cancel_invitation(p_company_id uuid,p_invitation_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if coalesce(public.np_user_role(p_company_id),'') <> 'admin' then raise exception 'Davet iptal yetkisi yok.'; end if;
  update public.company_invitations set status='cancelled' where company_id=p_company_id and id=p_invitation_id;
end; $$;

create or replace function public.np_request_subscription(p_company_id uuid,p_plan_code text,p_note text)
returns table(id uuid,company_id uuid,plan_code text,note text,status text,created_at timestamptz)
language plpgsql security definer set search_path=public as $$
declare v_id uuid; begin
  if coalesce(public.np_user_role(p_company_id),'') <> 'admin' then raise exception 'Paket talebi icin yonetici yetkisi gerekir.'; end if;
  insert into public.subscription_requests(company_id,requester_id,requester_email,plan_code,note) values(p_company_id,auth.uid(),auth.jwt()->>'email',p_plan_code,p_note) returning subscription_requests.id into v_id;
  return query select sr.id,sr.company_id,sr.plan_code,sr.note,sr.status,sr.created_at from public.subscription_requests sr where sr.id=v_id;
end; $$;

create or replace function public.np_get_subscription_requests(p_company_id uuid)
returns table(id uuid,company_id uuid,plan_code text,note text,status text,created_at timestamptz)
language sql stable security definer set search_path=public as $$
  select sr.id,sr.company_id,sr.plan_code,sr.note,sr.status,sr.created_at from public.subscription_requests sr where sr.company_id=p_company_id and public.np_user_role(p_company_id)='admin' order by sr.created_at desc;
$$;

create or replace function public.np_request_account_deletion(p_company_id uuid,p_reason text)
returns table(id uuid,status text,created_at timestamptz)
language plpgsql security definer set search_path=public as $$
declare v_id uuid; begin
  if not public.np_is_company_member(p_company_id) then raise exception 'Yetki yok.'; end if;
  insert into public.account_deletion_requests(company_id,requester_id,requester_email,reason) values(p_company_id,auth.uid(),auth.jwt()->>'email',p_reason) returning account_deletion_requests.id into v_id;
  return query select adr.id,adr.status,adr.created_at from public.account_deletion_requests adr where adr.id=v_id;
end; $$;

create or replace function public.np_log_client_activity(p_company_id uuid,p_action text,p_description text,p_entity_type text,p_entity_id text,p_metadata jsonb)
returns void language plpgsql security definer set search_path=public as $$
begin
  insert into public.audit_logs(company_id,user_id,user_email,action,description,entity_type,entity_id,metadata) values(p_company_id,auth.uid(),auth.jwt()->>'email',coalesce(p_action,'client.event'),p_description,p_entity_type,p_entity_id,coalesce(p_metadata,'{}'::jsonb));
end; $$;

create or replace function public.np_get_app_admin_context()
returns table(app_admin_role text,is_app_admin boolean)
language sql stable security definer set search_path=public as $$
  select case when public.np_is_primary_marmara_admin() then 'owner' else null end, public.np_is_primary_marmara_admin();
$$;

-- Ayar talebi fonksiyonlari
create or replace function public.np_create_settings_request(p_company_id uuid,p_request_type text,p_title text,p_payload jsonb default '{}'::jsonb)
returns table(id uuid,company_id uuid,requester_id uuid,requester_email text,request_type text,title text,payload jsonb,status text,admin_note text,admin_email text,created_at timestamptz,decided_at timestamptz,applied_at timestamptz)
language plpgsql security definer set search_path=public as $$
declare v_row public.settings_change_requests%rowtype; begin
  if auth.uid() is null then raise exception 'Giris yapmadan ayar talebi olusturulamaz.'; end if;
  if not public.np_is_company_member(p_company_id) then raise exception 'Bu firma icin yetkiniz yok.'; end if;
  insert into public.settings_change_requests(company_id,requester_id,requester_email,request_type,title,payload) values(p_company_id,auth.uid(),coalesce(auth.jwt()->>'email','bilinmeyen'),p_request_type,left(coalesce(nullif(trim(p_title),''),'Ayar talebi'),180),coalesce(p_payload,'{}'::jsonb)) returning * into v_row;
  return query select v_row.id,v_row.company_id,v_row.requester_id,v_row.requester_email,v_row.request_type,v_row.title,v_row.payload,v_row.status,v_row.admin_note,v_row.admin_email,v_row.created_at,v_row.decided_at,v_row.applied_at;
end; $$;

create or replace function public.np_get_settings_requests(p_company_id uuid)
returns table(id uuid,company_id uuid,requester_id uuid,requester_email text,request_type text,title text,payload jsonb,status text,admin_note text,admin_email text,created_at timestamptz,decided_at timestamptz,applied_at timestamptz)
language sql stable security definer set search_path=public as $$
  select scr.id,scr.company_id,scr.requester_id,scr.requester_email,scr.request_type,scr.title,scr.payload,scr.status,scr.admin_note,scr.admin_email,scr.created_at,scr.decided_at,scr.applied_at
  from public.settings_change_requests scr
  where scr.company_id=p_company_id and (public.np_user_role(p_company_id)='admin' or scr.requester_id=auth.uid())
  order by case when scr.status='pending' then 0 else 1 end, scr.created_at desc;
$$;

create or replace function public.np_decide_settings_request(p_company_id uuid,p_request_id uuid,p_decision text,p_admin_note text default null)
returns void language plpgsql security definer set search_path=public as $$
begin
  if public.np_user_role(p_company_id)<>'admin' then raise exception 'Ayar talebini sadece yonetici onaylayabilir.'; end if;
  update public.settings_change_requests set status=p_decision,admin_id=auth.uid(),admin_email=auth.jwt()->>'email',admin_note=nullif(trim(coalesce(p_admin_note,'')),''),decided_at=now() where id=p_request_id and company_id=p_company_id and status='pending';
  if not found then raise exception 'Bekleyen ayar talebi bulunamadi.'; end if;
end; $$;

create or replace function public.np_mark_settings_request_applied(p_company_id uuid,p_request_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.settings_change_requests set status='applied',applied_at=now() where id=p_request_id and company_id=p_company_id and requester_id=auth.uid() and status='approved';
  if not found then raise exception 'Uygulanacak onayli talep bulunamadi.'; end if;
end; $$;

-- Destek ve admin fonksiyonlari basit uyumlu cevaplar
create or replace function public.np_create_support_ticket(p_company_id uuid,p_type text,p_priority text,p_subject text,p_message text)
returns table(id uuid,status text,created_at timestamptz)
language plpgsql security definer set search_path=public as $$
declare v_id uuid; begin
  insert into public.support_tickets(company_id,requester_id,requester_email,type,priority,subject,message) values(p_company_id,auth.uid(),auth.jwt()->>'email',p_type,p_priority,p_subject,p_message) returning support_tickets.id into v_id;
  return query select st.id,st.status,st.created_at from public.support_tickets st where st.id=v_id;
end; $$;

create or replace function public.np_get_my_support_tickets()
returns setof public.support_tickets language sql stable security definer set search_path=public as $$
  select * from public.support_tickets where requester_id=auth.uid() order by created_at desc;
$$;

create or replace function public.np_admin_get_dashboard()
returns table(total_users bigint,total_companies bigint,total_tickets bigint,total_deletion_requests bigint)
language sql stable security definer set search_path=public as $$
  select (select count(*) from auth.users),(select count(*) from public.companies),(select count(*) from public.support_tickets),(select count(*) from public.account_deletion_requests)
  where public.np_is_primary_marmara_admin();
$$;

create or replace function public.np_admin_get_users(p_search text default null,p_limit integer default 50)
returns table(user_id uuid,email text,created_at timestamptz,last_sign_in_at timestamptz,app_admin_role text,company_count bigint,support_ticket_count bigint,deletion_request_count bigint)
language sql stable security definer set search_path=public as $$
  select u.id,u.email,u.created_at,u.last_sign_in_at,case when lower(u.email)='tburak.kus@marmarateknikmakine.com.tr' then 'owner' else null end,
    (select count(*) from public.company_members cm where cm.user_id=u.id),
    (select count(*) from public.support_tickets st where st.requester_id=u.id),
    (select count(*) from public.account_deletion_requests adr where adr.requester_id=u.id)
  from auth.users u
  where public.np_is_primary_marmara_admin() and (p_search is null or lower(u.email) like '%'||lower(p_search)||'%')
  order by u.created_at desc limit least(coalesce(p_limit,50),200);
$$;

create or replace function public.np_admin_get_support_tickets(p_status text default null,p_type text default null,p_search text default null)
returns setof public.support_tickets language sql stable security definer set search_path=public as $$
  select * from public.support_tickets st where public.np_is_primary_marmara_admin()
    and (p_status is null or st.status=p_status) and (p_type is null or st.type=p_type)
    and (p_search is null or lower(st.subject||' '||st.message||' '||coalesce(st.requester_email,'')) like '%'||lower(p_search)||'%')
  order by st.created_at desc;
$$;

create or replace function public.np_admin_update_support_ticket(p_ticket_id uuid,p_status text,p_admin_note text default null)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.np_is_primary_marmara_admin() then raise exception 'Admin yetkisi gerekli.'; end if;
  update public.support_tickets set status=coalesce(p_status,status),admin_note=p_admin_note,updated_at=now() where id=p_ticket_id;
end; $$;

create or replace function public.np_admin_get_account_deletion_requests(p_status text default null,p_search text default null)
returns setof public.account_deletion_requests language sql stable security definer set search_path=public as $$
  select * from public.account_deletion_requests adr where public.np_is_primary_marmara_admin()
    and (p_status is null or adr.status=p_status)
    and (p_search is null or lower(coalesce(adr.requester_email,'')||' '||coalesce(adr.reason,'')) like '%'||lower(p_search)||'%')
  order by adr.created_at desc;
$$;

create or replace function public.np_admin_get_audit_logs(p_company_id uuid default null,p_search text default null,p_limit integer default 100)
returns setof public.audit_logs language sql stable security definer set search_path=public as $$
  select * from public.audit_logs al where public.np_is_primary_marmara_admin()
    and (p_company_id is null or al.company_id=p_company_id)
    and (p_search is null or lower(al.action||' '||coalesce(al.description,'')||' '||coalesce(al.user_email,'')) like '%'||lower(p_search)||'%')
  order by al.created_at desc limit least(coalesce(p_limit,100),300);
$$;

-- Marmara ana admin kullanicisini tum firmalara admin ekle.
insert into public.company_members(company_id,user_id,role,status)
select c.id,u.id,'admin','active' from public.companies c join auth.users u on lower(u.email)='tburak.kus@marmarateknikmakine.com.tr'
on conflict(company_id,user_id) do update set role='admin',status='active',updated_at=now();

-- Eger hic firma yoksa ve ana admin kullanicisi varsa Marmara Teknik firmasini olustur.
do $$
declare v_user uuid; v_company uuid; v_old jsonb; begin
  select id into v_user from auth.users where lower(email)='tburak.kus@marmarateknikmakine.com.tr' limit 1;
  if v_user is not null and not exists(select 1 from public.companies) then
    insert into public.companies(name,owner_id,plan_code,subscription_status) values('MARMARA TEKNIK',v_user,'internal','active') returning id into v_company;
    insert into public.company_members(company_id,user_id,role,status) values(v_company,v_user,'admin','active') on conflict do nothing;
    -- Eski Firma Finans tablosu varsa veriyi tasimaya calis.
    if to_regclass('public.firma_finans_company_data') is not null then
      execute $q$select data from public.firma_finans_company_data where company_key='marmara_teknik' limit 1$q$ into v_old;
    end if;
    insert into public.company_data(company_id,data,updated_by) values(v_company,coalesce(v_old,'{}'::jsonb),v_user) on conflict(company_id) do update set data=excluded.data,updated_at=now();
  end if;
end $$;

-- RLS politikalarini sade tut: dogrudan tablo erisimi kapali; RPC kullanilir.
-- Gerekli execute izinleri
grant usage on schema public to authenticated;
grant execute on function public.np_is_primary_marmara_admin() to authenticated;
grant execute on function public.np_is_company_active(uuid) to authenticated;
grant execute on function public.np_user_role(uuid) to authenticated;
grant execute on function public.np_is_company_member(uuid) to authenticated;
grant execute on function public.np_get_my_companies() to authenticated;
grant execute on function public.np_create_company(text) to authenticated;
grant execute on function public.np_get_company_data(uuid) to authenticated;
grant execute on function public.np_save_company_data(uuid,jsonb) to authenticated;
grant execute on function public.np_add_daily_record(uuid,text,jsonb) to authenticated;
grant execute on function public.np_update_daily_record_link(uuid,text,text,text,text,text) to authenticated;
grant execute on function public.np_create_company_backup(uuid,text,jsonb) to authenticated;
grant execute on function public.np_invite_member(uuid,text,text) to authenticated;
grant execute on function public.np_accept_invitation(text) to authenticated;
grant execute on function public.np_get_team(uuid) to authenticated;
grant execute on function public.np_update_member_role(uuid,uuid,text) to authenticated;
grant execute on function public.np_remove_member(uuid,uuid) to authenticated;
grant execute on function public.np_cancel_invitation(uuid,uuid) to authenticated;
grant execute on function public.np_request_subscription(uuid,text,text) to authenticated;
grant execute on function public.np_get_subscription_requests(uuid) to authenticated;
grant execute on function public.np_request_account_deletion(uuid,text) to authenticated;
grant execute on function public.np_log_client_activity(uuid,text,text,text,text,jsonb) to authenticated;
grant execute on function public.np_get_app_admin_context() to authenticated;
grant execute on function public.np_create_settings_request(uuid,text,text,jsonb) to authenticated;
grant execute on function public.np_get_settings_requests(uuid) to authenticated;
grant execute on function public.np_decide_settings_request(uuid,uuid,text,text) to authenticated;
grant execute on function public.np_mark_settings_request_applied(uuid,uuid) to authenticated;
grant execute on function public.np_create_support_ticket(uuid,text,text,text,text) to authenticated;
grant execute on function public.np_get_my_support_tickets() to authenticated;
grant execute on function public.np_admin_get_dashboard() to authenticated;
grant execute on function public.np_admin_get_users(text,integer) to authenticated;
grant execute on function public.np_admin_get_support_tickets(text,text,text) to authenticated;
grant execute on function public.np_admin_update_support_ticket(uuid,text,text) to authenticated;
grant execute on function public.np_admin_get_account_deletion_requests(text,text) to authenticated;
grant execute on function public.np_admin_get_audit_logs(uuid,text,integer) to authenticated;
