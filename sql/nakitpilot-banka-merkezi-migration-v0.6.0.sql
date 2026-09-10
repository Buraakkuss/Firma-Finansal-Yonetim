-- NakitPilot Banka Merkezi Migration
-- Sürüm: v0.6.0
-- Tarih: 22.07.2026
-- Bu dosya mevcut MT-PRO-Finans kurulumundan SONRA bir kez çalıştırılmalıdır.
-- Mevcut company_data JSON kayıtlarını silmez. Banka verilerini hareket bazlı,
-- firma ayrımlı ve denetlenebilir tablolara atomik olarak aynalar.

begin;

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1) Kullanıcı bazlı ayrıntılı finans yetkileri
-- ---------------------------------------------------------------------------
create table if not exists public.company_finance_permissions (
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  view_banks boolean,
  manage_banks boolean,
  view_movements boolean,
  make_transfers boolean,
  manage_income_expense boolean,
  manage_credit_cards boolean,
  manage_overdrafts boolean,
  manage_investments boolean,
  download_reports boolean,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(company_id,user_id)
);

create or replace function public.np_has_finance_permission(p_company_id uuid,p_permission text)
returns boolean
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_role text;
  v_override boolean;
begin
  if not public.np_is_company_member(p_company_id) then return false; end if;
  v_role:=coalesce(public.np_user_role(p_company_id),'');
  execute format('select %I from public.company_finance_permissions where company_id=$1 and user_id=auth.uid()',p_permission)
    into v_override using p_company_id;
  if v_override is not null then return v_override; end if;

  if v_role='admin' then return true; end if;
  if v_role='accounting' then
    return p_permission in ('view_banks','view_movements','make_transfers','manage_income_expense','manage_credit_cards','manage_overdrafts','manage_investments','download_reports');
  end if;
  if v_role='viewer' then
    return p_permission in ('view_banks','view_movements','download_reports');
  end if;
  return false;
exception when undefined_column then
  return false;
end;
$$;

create or replace function public.np_finance_permissions_json(p_company_id uuid)
returns jsonb
language sql
stable
security definer
set search_path=public
as $$
  select jsonb_build_object(
    'view_banks',public.np_has_finance_permission(p_company_id,'view_banks'),
    'manage_banks',public.np_has_finance_permission(p_company_id,'manage_banks'),
    'view_movements',public.np_has_finance_permission(p_company_id,'view_movements'),
    'make_transfers',public.np_has_finance_permission(p_company_id,'make_transfers'),
    'manage_income_expense',public.np_has_finance_permission(p_company_id,'manage_income_expense'),
    'manage_credit_cards',public.np_has_finance_permission(p_company_id,'manage_credit_cards'),
    'manage_overdrafts',public.np_has_finance_permission(p_company_id,'manage_overdrafts'),
    'manage_investments',public.np_has_finance_permission(p_company_id,'manage_investments'),
    'download_reports',public.np_has_finance_permission(p_company_id,'download_reports')
  );
$$;

-- Mevcut company_data kaydını koruyarak banka verisini yalnızca yetkili kullanıcıya döndür.
-- Uygulama izinleri app_data içine özel bir anahtarla eklenir; kayıt sırasında normalize edilmez.
create or replace function public.np_company_payload(p_company_id uuid)
returns setof public.np_company_payload_row
language sql stable security definer set search_path=public as $$
  select c.id, c.name, public.np_user_role(c.id), c.plan_code, c.subscription_status, c.trial_ends_at,
    case when c.trial_ends_at is null then null::integer else greatest(0,ceil(extract(epoch from (c.trial_ends_at-now()))/86400.0))::integer end,
    true, coalesce(public.np_user_role(c.id),'') in ('admin','accounting'), false,
    (case when public.np_has_finance_permission(c.id,'view_banks')
      then coalesce(cd.data,'{}'::jsonb)
      else coalesce(cd.data,'{}'::jsonb)-'banking'-'creditCards'-'creditCardPayments'
     end) || jsonb_build_object('_financePermissions',public.np_finance_permissions_json(c.id)),
    coalesce(cd.updated_at,c.updated_at), c.created_at
  from public.companies c
  left join public.company_data cd on cd.company_id=c.id
  where c.id=p_company_id and public.np_is_company_member(c.id);
$$;

-- ---------------------------------------------------------------------------
-- 2) Banka / hesap / hareket tabloları
-- Uygulamadaki kimlikler metin tabanlı olduğu için id alanları text tutulur.
-- Firma kimliği her anahtarın zorunlu parçasıdır.
-- ---------------------------------------------------------------------------
create table if not exists public.financial_institutions (
  company_id uuid not null references public.companies(id) on delete cascade,
  id text not null,
  name text not null,
  icon text,
  branch text,
  owner_name text,
  iban text,
  description text,
  notes text,
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(company_id,id)
);

create table if not exists public.bank_accounts (
  company_id uuid not null,
  id text not null,
  institution_id text not null,
  name text not null,
  account_type text not null default 'checking',
  currency text not null default 'TRY' check(currency in ('TRY','EUR','USD','GOLD')),
  opening_balance numeric(22,6) not null default 0,
  blocked_amount numeric(22,6) not null default 0 check(blocked_amount>=0),
  iban text,
  open_date date,
  maturity_date date,
  yield_rate numeric(12,6) not null default 0,
  tax_rate numeric(12,6) not null default 0,
  description text,
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(company_id,id),
  foreign key(company_id,institution_id) references public.financial_institutions(company_id,id) on delete restrict
);

create table if not exists public.bank_account_transactions (
  company_id uuid not null,
  id text not null,
  account_id text not null,
  transaction_date date not null,
  transaction_type text not null,
  direction text not null check(direction in ('in','out')),
  amount numeric(22,6) not null check(amount>=0),
  currency text not null check(currency in ('TRY','EUR','USD','GOLD')),
  description text,
  category text,
  counter_account_id text,
  counter_label text,
  source_type text,
  source_id text,
  reference_no text,
  status text not null default 'active' check(status in ('active','cancelled','reversed')),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(company_id,id),
  foreign key(company_id,account_id) references public.bank_accounts(company_id,id) on delete cascade,
  unique(company_id,source_type,source_id,account_id,direction,id)
);

create table if not exists public.credit_cards (
  company_id uuid not null,
  id text not null,
  institution_id text,
  name text not null,
  last_four text,
  currency text not null default 'TRY' check(currency in ('TRY','EUR','USD')),
  total_limit numeric(22,2) not null default 0,
  opening_debt numeric(22,2) not null default 0,
  pending_authorization numeric(22,2) not null default 0,
  installment_total numeric(22,2) not null default 0,
  previous_period_debt numeric(22,2) not null default 0,
  minimum_payment numeric(22,2) not null default 0,
  statement_day integer check(statement_day between 1 and 31),
  due_day integer check(due_day between 1 and 31),
  linked_account_id text,
  description text,
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(company_id,id),
  foreign key(company_id,institution_id) references public.financial_institutions(company_id,id) on delete set null,
  foreign key(company_id,linked_account_id) references public.bank_accounts(company_id,id) on delete set null
);

create table if not exists public.credit_card_transactions (
  company_id uuid not null,
  id text not null,
  card_id text not null,
  transaction_date date not null,
  transaction_type text not null,
  direction text not null check(direction in ('increase','decrease')),
  amount numeric(22,2) not null check(amount>=0),
  description text,
  source_type text,
  source_id text,
  from_account_id text,
  installment_count integer not null default 1,
  reference_no text,
  status text not null default 'active' check(status in ('active','cancelled','reversed')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key(company_id,id),
  foreign key(company_id,card_id) references public.credit_cards(company_id,id) on delete cascade,
  foreign key(company_id,from_account_id) references public.bank_accounts(company_id,id) on delete set null
);

create table if not exists public.credit_card_installments (
  company_id uuid not null,
  id text not null,
  card_id text not null,
  transaction_id text not null,
  installment_no integer not null,
  installment_count integer not null,
  amount numeric(22,2) not null,
  due_month text not null,
  status text not null default 'planned' check(status in ('planned','posted','paid','cancelled')),
  created_at timestamptz not null default now(),
  primary key(company_id,id),
  foreign key(company_id,card_id) references public.credit_cards(company_id,id) on delete cascade,
  foreign key(company_id,transaction_id) references public.credit_card_transactions(company_id,id) on delete cascade
);

create table if not exists public.overdraft_accounts (
  company_id uuid not null,
  id text not null,
  institution_id text not null,
  linked_account_id text,
  name text not null,
  currency text not null default 'TRY' check(currency in ('TRY','EUR','USD')),
  total_limit numeric(22,2) not null default 0,
  opening_debt numeric(22,2) not null default 0,
  interest_rate numeric(12,6) not null default 0,
  due_date date,
  accrual_date date,
  description text,
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(company_id,id),
  foreign key(company_id,institution_id) references public.financial_institutions(company_id,id) on delete restrict,
  foreign key(company_id,linked_account_id) references public.bank_accounts(company_id,id) on delete set null
);

create table if not exists public.overdraft_transactions (
  company_id uuid not null,
  id text not null,
  overdraft_id text not null,
  transaction_date date not null,
  transaction_type text not null,
  amount numeric(22,2) not null check(amount>=0),
  bank_account_id text,
  description text,
  reference_no text,
  source_type text,
  source_id text,
  status text not null default 'active' check(status in ('active','cancelled','reversed')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key(company_id,id),
  foreign key(company_id,overdraft_id) references public.overdraft_accounts(company_id,id) on delete cascade,
  foreign key(company_id,bank_account_id) references public.bank_accounts(company_id,id) on delete set null
);

create table if not exists public.investment_accounts (
  company_id uuid not null,
  account_id text not null,
  institution_id text not null,
  investment_type text not null,
  currency text not null,
  opening_value numeric(22,6) not null default 0,
  maturity_date date,
  yield_rate numeric(12,6) not null default 0,
  tax_rate numeric(12,6) not null default 0,
  active boolean not null default true,
  primary key(company_id,account_id),
  foreign key(company_id,account_id) references public.bank_accounts(company_id,id) on delete cascade,
  foreign key(company_id,institution_id) references public.financial_institutions(company_id,id) on delete cascade
);

create table if not exists public.term_deposits (
  company_id uuid not null,
  account_id text not null,
  principal numeric(22,6) not null default 0,
  start_date date,
  maturity_date date,
  gross_interest_rate numeric(12,6) not null default 0,
  withholding_rate numeric(12,6) not null default 0,
  status text not null default 'active',
  primary key(company_id,account_id),
  foreign key(company_id,account_id) references public.bank_accounts(company_id,id) on delete cascade
);

create table if not exists public.investment_transactions (
  company_id uuid not null,
  id text not null,
  investment_account_id text not null,
  bank_account_id text,
  transaction_date date not null,
  transaction_type text not null,
  quantity numeric(24,8) not null default 0,
  unit_price numeric(24,8) not null default 0,
  total_amount numeric(22,6) not null default 0,
  commission numeric(22,6) not null default 0,
  tax numeric(22,6) not null default 0,
  realized_pnl numeric(22,6) not null default 0,
  current_unit_price numeric(24,8) not null default 0,
  unrealized_pnl numeric(22,6) not null default 0,
  description text,
  reference_no text,
  status text not null default 'active' check(status in ('active','cancelled','reversed')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key(company_id,id),
  foreign key(company_id,investment_account_id) references public.bank_accounts(company_id,id) on delete cascade,
  foreign key(company_id,bank_account_id) references public.bank_accounts(company_id,id) on delete set null
);

create table if not exists public.account_transfers (
  company_id uuid not null,
  id text not null,
  transfer_date date not null,
  from_account_id text not null,
  to_account_id text not null,
  from_amount numeric(22,6) not null check(from_amount>0),
  to_amount numeric(22,6) not null check(to_amount>0),
  from_currency text not null,
  to_currency text not null,
  exchange_rate numeric(24,10) not null default 1,
  bank_fee numeric(22,6) not null default 0,
  tax_or_commission numeric(22,6) not null default 0,
  realized_pnl numeric(22,6) not null default 0,
  description text,
  reference_no text,
  fee_expense_id text,
  status text not null default 'active' check(status in ('active','cancelled','reversed')),
  created_by uuid references auth.users(id) on delete set null,
  cancelled_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  cancelled_at timestamptz,
  primary key(company_id,id),
  foreign key(company_id,from_account_id) references public.bank_accounts(company_id,id) on delete restrict,
  foreign key(company_id,to_account_id) references public.bank_accounts(company_id,id) on delete restrict,
  check(from_account_id<>to_account_id)
);

create table if not exists public.payment_allocations (
  company_id uuid not null,
  id text not null,
  parent_type text not null check(parent_type in ('income','expense')),
  parent_id text not null,
  payment_method text not null,
  bank_account_id text,
  credit_card_id text,
  overdraft_id text,
  amount numeric(22,6) not null check(amount>0),
  account_amount numeric(22,6) not null check(account_amount>0),
  currency text not null,
  exchange_rate numeric(24,10) not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(company_id,id),
  unique(company_id,parent_type,parent_id,id),
  foreign key(company_id,bank_account_id) references public.bank_accounts(company_id,id) on delete set null,
  foreign key(company_id,credit_card_id) references public.credit_cards(company_id,id) on delete set null,
  foreign key(company_id,overdraft_id) references public.overdraft_accounts(company_id,id) on delete set null
);

-- Kısmi/önceki denemelerde tablo oluşturulmuşsa yeni denetim alanlarını güvenle tamamla.
alter table public.payment_allocations add column if not exists created_by uuid references auth.users(id) on delete set null;
alter table public.payment_allocations add column if not exists updated_by uuid references auth.users(id) on delete set null;
alter table public.payment_allocations add column if not exists created_at timestamptz not null default now();
alter table public.payment_allocations add column if not exists updated_at timestamptz not null default now();

create table if not exists public.finance_reversals (
  company_id uuid not null,
  id text not null,
  entity_type text not null,
  entity_id text not null,
  snapshot jsonb not null default '{}'::jsonb,
  reason text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key(company_id,id)
);

-- ---------------------------------------------------------------------------
-- 3) İndeksler
-- ---------------------------------------------------------------------------
create index if not exists bank_accounts_company_bank_idx on public.bank_accounts(company_id,institution_id,active);
create index if not exists bank_transactions_account_date_idx on public.bank_account_transactions(company_id,account_id,transaction_date desc);
create index if not exists bank_transactions_source_idx on public.bank_account_transactions(company_id,source_type,source_id);
create index if not exists credit_cards_company_bank_idx on public.credit_cards(company_id,institution_id,active);
create index if not exists credit_card_transactions_card_date_idx on public.credit_card_transactions(company_id,card_id,transaction_date desc);
create index if not exists overdraft_company_bank_idx on public.overdraft_accounts(company_id,institution_id,active);
create index if not exists investment_transactions_account_date_idx on public.investment_transactions(company_id,investment_account_id,transaction_date desc);
create index if not exists transfers_company_date_idx on public.account_transfers(company_id,transfer_date desc);
create index if not exists payment_allocations_parent_idx on public.payment_allocations(company_id,parent_type,parent_id);

-- ---------------------------------------------------------------------------
-- 4) RLS
-- ---------------------------------------------------------------------------
alter table public.company_finance_permissions enable row level security;
alter table public.financial_institutions enable row level security;
alter table public.bank_accounts enable row level security;
alter table public.bank_account_transactions enable row level security;
alter table public.credit_cards enable row level security;
alter table public.credit_card_transactions enable row level security;
alter table public.credit_card_installments enable row level security;
alter table public.overdraft_accounts enable row level security;
alter table public.overdraft_transactions enable row level security;
alter table public.investment_accounts enable row level security;
alter table public.term_deposits enable row level security;
alter table public.investment_transactions enable row level security;
alter table public.account_transfers enable row level security;
alter table public.payment_allocations enable row level security;
alter table public.finance_reversals enable row level security;

-- Tekrarlanabilir kurulum için eski politika adlarını temizle.
do $$
declare t text;
begin
  foreach t in array array['company_finance_permissions','financial_institutions','bank_accounts','bank_account_transactions','credit_cards','credit_card_transactions','credit_card_installments','overdraft_accounts','overdraft_transactions','investment_accounts','term_deposits','investment_transactions','account_transfers','payment_allocations','finance_reversals'] loop
    execute format('drop policy if exists %I_select on public.%I',t,t);
    execute format('drop policy if exists %I_write on public.%I',t,t);
  end loop;
end $$;

create policy company_finance_permissions_select on public.company_finance_permissions for select using(public.np_is_company_member(company_id));
create policy company_finance_permissions_write on public.company_finance_permissions for all using(coalesce(public.np_user_role(company_id),'')='admin') with check(coalesce(public.np_user_role(company_id),'')='admin');

-- Görüntüleme politikaları
do $$
declare t text;
begin
  foreach t in array array['financial_institutions','bank_accounts','bank_account_transactions','credit_cards','credit_card_transactions','credit_card_installments','overdraft_accounts','overdraft_transactions','investment_accounts','term_deposits','investment_transactions','account_transfers','payment_allocations','finance_reversals'] loop
    execute format('create policy %I_select on public.%I for select using(public.np_has_finance_permission(company_id,''view_banks''))',t,t);
  end loop;
end $$;

create policy financial_institutions_write on public.financial_institutions for all using(public.np_has_finance_permission(company_id,'manage_banks')) with check(public.np_has_finance_permission(company_id,'manage_banks'));
create policy bank_accounts_write on public.bank_accounts for all using(public.np_has_finance_permission(company_id,'manage_banks')) with check(public.np_has_finance_permission(company_id,'manage_banks'));
create policy bank_account_transactions_write on public.bank_account_transactions for all using(public.np_has_finance_permission(company_id,'manage_income_expense')) with check(public.np_has_finance_permission(company_id,'manage_income_expense'));
create policy credit_cards_write on public.credit_cards for all using(public.np_has_finance_permission(company_id,'manage_credit_cards')) with check(public.np_has_finance_permission(company_id,'manage_credit_cards'));
create policy credit_card_transactions_write on public.credit_card_transactions for all using(public.np_has_finance_permission(company_id,'manage_credit_cards')) with check(public.np_has_finance_permission(company_id,'manage_credit_cards'));
create policy credit_card_installments_write on public.credit_card_installments for all using(public.np_has_finance_permission(company_id,'manage_credit_cards')) with check(public.np_has_finance_permission(company_id,'manage_credit_cards'));
create policy overdraft_accounts_write on public.overdraft_accounts for all using(public.np_has_finance_permission(company_id,'manage_overdrafts')) with check(public.np_has_finance_permission(company_id,'manage_overdrafts'));
create policy overdraft_transactions_write on public.overdraft_transactions for all using(public.np_has_finance_permission(company_id,'manage_overdrafts')) with check(public.np_has_finance_permission(company_id,'manage_overdrafts'));
create policy investment_accounts_write on public.investment_accounts for all using(public.np_has_finance_permission(company_id,'manage_investments')) with check(public.np_has_finance_permission(company_id,'manage_investments'));
create policy term_deposits_write on public.term_deposits for all using(public.np_has_finance_permission(company_id,'manage_investments')) with check(public.np_has_finance_permission(company_id,'manage_investments'));
create policy investment_transactions_write on public.investment_transactions for all using(public.np_has_finance_permission(company_id,'manage_investments')) with check(public.np_has_finance_permission(company_id,'manage_investments'));
create policy account_transfers_write on public.account_transfers for all using(public.np_has_finance_permission(company_id,'make_transfers')) with check(public.np_has_finance_permission(company_id,'make_transfers'));
create policy payment_allocations_write on public.payment_allocations for all using(public.np_has_finance_permission(company_id,'manage_income_expense')) with check(public.np_has_finance_permission(company_id,'manage_income_expense'));
create policy finance_reversals_write on public.finance_reversals for all using(coalesce(public.np_user_role(company_id),'')='admin') with check(coalesce(public.np_user_role(company_id),'')='admin');

-- ---------------------------------------------------------------------------
-- 5) JSON ana kaydı -> normalize tablo aynalama
-- Uygulama company_data.data alanını atomik kaydetmeye devam eder. Bu fonksiyon aynı
-- transaction içinde normalize tabloları yeniler. Böylece yarım transfer oluşmaz.
-- ---------------------------------------------------------------------------
create or replace function public.np_json_uuid(v text)
returns uuid language plpgsql immutable as $$
begin
  if v is null or btrim(v)='' then return null; end if;
  return v::uuid;
exception when others then return null;
end $$;

create or replace function public.np_sync_company_banking_snapshot(p_company_id uuid,p_data jsonb)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  j jsonb;
  r jsonb;
  a jsonb;
  v_parent_type text;
  v_parent_id text;
  v_method text;
  v_created_by uuid;
begin
  if p_company_id is null then return; end if;
  v_created_by:=auth.uid();
  j:=coalesce(p_data,'{}'::jsonb);

  -- Bağımlılık sırasına göre temizle.
  delete from public.credit_card_installments where company_id=p_company_id;
  delete from public.credit_card_transactions where company_id=p_company_id;
  delete from public.overdraft_transactions where company_id=p_company_id;
  delete from public.investment_transactions where company_id=p_company_id;
  delete from public.payment_allocations where company_id=p_company_id;
  delete from public.account_transfers where company_id=p_company_id;
  delete from public.finance_reversals where company_id=p_company_id;
  delete from public.term_deposits where company_id=p_company_id;
  delete from public.investment_accounts where company_id=p_company_id;
  delete from public.bank_account_transactions where company_id=p_company_id;
  delete from public.credit_cards where company_id=p_company_id;
  delete from public.overdraft_accounts where company_id=p_company_id;
  delete from public.bank_accounts where company_id=p_company_id;
  delete from public.financial_institutions where company_id=p_company_id;

  for r in select value from jsonb_array_elements(coalesce(j#>'{banking,banks}','[]'::jsonb)) loop
    insert into public.financial_institutions(company_id,id,name,icon,branch,owner_name,iban,description,notes,active,created_by,updated_by,created_at,updated_at)
    values(p_company_id,r->>'id',coalesce(nullif(r->>'name',''),'İsimsiz Banka'),r->>'icon',r->>'branch',r->>'owner',r->>'iban',r->>'description',r->>'notes',coalesce((r->>'active')::boolean,true),coalesce(public.np_json_uuid(r->>'createdBy'),v_created_by),coalesce(public.np_json_uuid(r->>'updatedBy'),v_created_by),coalesce((r->>'createdAt')::timestamptz,now()),coalesce((r->>'updatedAt')::timestamptz,now()));
  end loop;

  for r in select value from jsonb_array_elements(coalesce(j#>'{banking,accounts}','[]'::jsonb)) loop
    if exists(select 1 from public.financial_institutions where company_id=p_company_id and id=r->>'bankId') then
      insert into public.bank_accounts(company_id,id,institution_id,name,account_type,currency,opening_balance,blocked_amount,iban,open_date,maturity_date,yield_rate,tax_rate,description,active,created_by,updated_by,created_at,updated_at)
      values(p_company_id,r->>'id',r->>'bankId',coalesce(nullif(r->>'name',''),'İsimsiz Hesap'),coalesce(nullif(r->>'type',''),'checking'),coalesce(nullif(r->>'currency',''),'TRY'),coalesce((r->>'openingBalance')::numeric,0),greatest(coalesce((r->>'blockedAmount')::numeric,0),0),r->>'iban',nullif(r->>'openDate','')::date,nullif(r->>'maturityDate','')::date,coalesce((r->>'yieldRate')::numeric,0),coalesce((r->>'taxRate')::numeric,0),r->>'description',coalesce((r->>'active')::boolean,true),coalesce(public.np_json_uuid(r->>'createdBy'),v_created_by),coalesce(public.np_json_uuid(r->>'updatedBy'),v_created_by),coalesce((r->>'createdAt')::timestamptz,now()),coalesce((r->>'updatedAt')::timestamptz,now()));
    end if;
  end loop;

  insert into public.investment_accounts(company_id,account_id,institution_id,investment_type,currency,opening_value,maturity_date,yield_rate,tax_rate,active)
  select company_id,id,institution_id,account_type,currency,opening_balance,maturity_date,yield_rate,tax_rate,active
  from public.bank_accounts where company_id=p_company_id and account_type in ('fund','investment','term_deposit','gold');

  insert into public.term_deposits(company_id,account_id,principal,start_date,maturity_date,gross_interest_rate,withholding_rate,status)
  select company_id,id,opening_balance,open_date,maturity_date,yield_rate,tax_rate,case when active then 'active' else 'passive' end
  from public.bank_accounts where company_id=p_company_id and account_type='term_deposit';

  for r in select value from jsonb_array_elements(coalesce(j->'creditCards','[]'::jsonb)) loop
    insert into public.credit_cards(company_id,id,institution_id,name,last_four,currency,total_limit,opening_debt,pending_authorization,installment_total,previous_period_debt,minimum_payment,statement_day,due_day,linked_account_id,description,active,created_by,updated_by,created_at,updated_at)
    values(p_company_id,r->>'id',case when exists(select 1 from public.financial_institutions where company_id=p_company_id and id=r->>'bankId') then r->>'bankId' else null end,coalesce(nullif(r->>'name',''),'İsimsiz Kart'),r->>'last4',coalesce(nullif(r->>'currency',''),'TRY'),coalesce((r->>'limit')::numeric,0),coalesce((coalesce(r->>'openingDebt',r->>'currentDebt'))::numeric,0),coalesce((r->>'pendingAuthorization')::numeric,0),coalesce((r->>'installmentTotal')::numeric,0),coalesce((r->>'previousDebt')::numeric,0),coalesce((r->>'minimumPayment')::numeric,0),nullif(r->>'statementDay','')::integer,nullif(r->>'dueDay','')::integer,case when exists(select 1 from public.bank_accounts where company_id=p_company_id and id=r->>'linkedAccountId') then r->>'linkedAccountId' else null end,r->>'description',coalesce((r->>'active')::boolean,true),coalesce(public.np_json_uuid(r->>'createdBy'),v_created_by),coalesce(public.np_json_uuid(r->>'updatedBy'),v_created_by),coalesce((r->>'createdAt')::timestamptz,now()),coalesce((r->>'updatedAt')::timestamptz,now()));
  end loop;

  for r in select value from jsonb_array_elements(coalesce(j#>'{banking,overdrafts}','[]'::jsonb)) loop
    if exists(select 1 from public.financial_institutions where company_id=p_company_id and id=r->>'bankId') then
      insert into public.overdraft_accounts(company_id,id,institution_id,linked_account_id,name,currency,total_limit,opening_debt,interest_rate,due_date,accrual_date,description,active,created_by,updated_by,created_at,updated_at)
      values(p_company_id,r->>'id',r->>'bankId',case when exists(select 1 from public.bank_accounts where company_id=p_company_id and id=r->>'linkedAccountId') then r->>'linkedAccountId' else null end,coalesce(nullif(r->>'name',''),'KMH'),coalesce(nullif(r->>'currency',''),'TRY'),coalesce((r->>'limit')::numeric,0),coalesce((coalesce(r->>'openingDebt',r->>'currentDebt'))::numeric,0),coalesce((r->>'interestRate')::numeric,0),nullif(r->>'dueDate','')::date,nullif(r->>'accrualDate','')::date,r->>'description',coalesce((r->>'active')::boolean,true),coalesce(public.np_json_uuid(r->>'createdBy'),v_created_by),coalesce(public.np_json_uuid(r->>'updatedBy'),v_created_by),coalesce((r->>'createdAt')::timestamptz,now()),coalesce((r->>'updatedAt')::timestamptz,now()));
    end if;
  end loop;

  for r in select value from jsonb_array_elements(coalesce(j#>'{banking,accountTransactions}','[]'::jsonb)) loop
    if exists(select 1 from public.bank_accounts where company_id=p_company_id and id=r->>'accountId') then
      insert into public.bank_account_transactions(company_id,id,account_id,transaction_date,transaction_type,direction,amount,currency,description,category,counter_account_id,counter_label,source_type,source_id,reference_no,status,created_by,updated_by,created_at,updated_at)
      values(p_company_id,r->>'id',r->>'accountId',coalesce(nullif(r->>'date','')::date,current_date),coalesce(nullif(r->>'type',''),'manual'),case when r->>'direction'='in' then 'in' else 'out' end,greatest(coalesce((r->>'amount')::numeric,0),0),coalesce(nullif(r->>'currency',''),'TRY'),r->>'description',r->>'category',r->>'counterAccountId',r->>'counterLabel',coalesce(nullif(r->>'sourceType',''),'manual'),r->>'sourceId',r->>'reference',coalesce(nullif(r->>'status',''),'active'),coalesce(public.np_json_uuid(r->>'createdBy'),v_created_by),coalesce(public.np_json_uuid(r->>'updatedBy'),v_created_by),coalesce((r->>'createdAt')::timestamptz,now()),coalesce((r->>'updatedAt')::timestamptz,now()));
    end if;
  end loop;

  for r in select value from jsonb_array_elements(coalesce(j#>'{banking,transfers}','[]'::jsonb)) loop
    if exists(select 1 from public.bank_accounts where company_id=p_company_id and id=r->>'fromAccountId') and exists(select 1 from public.bank_accounts where company_id=p_company_id and id=r->>'toAccountId') then
      insert into public.account_transfers(company_id,id,transfer_date,from_account_id,to_account_id,from_amount,to_amount,from_currency,to_currency,exchange_rate,bank_fee,tax_or_commission,realized_pnl,description,reference_no,fee_expense_id,status,created_by,cancelled_by,created_at,cancelled_at)
      values(p_company_id,r->>'id',coalesce(nullif(r->>'date','')::date,current_date),r->>'fromAccountId',r->>'toAccountId',coalesce((r->>'fromAmount')::numeric,0),coalesce((r->>'toAmount')::numeric,0),coalesce(nullif(r->>'fromCurrency',''),'TRY'),coalesce(nullif(r->>'toCurrency',''),'TRY'),coalesce((r->>'rate')::numeric,1),coalesce((r->>'fee')::numeric,0),coalesce((r->>'tax')::numeric,0),coalesce((r->>'realizedPnl')::numeric,0),r->>'description',r->>'reference',r->>'feeExpenseId',coalesce(nullif(r->>'status',''),'active'),coalesce(public.np_json_uuid(r->>'createdBy'),v_created_by),coalesce(public.np_json_uuid(r->>'cancelledBy'),v_created_by),coalesce((r->>'createdAt')::timestamptz,now()),nullif(r->>'cancelledAt','')::timestamptz);
    end if;
  end loop;

  for r in select value from jsonb_array_elements(coalesce(j#>'{banking,overdraftTransactions}','[]'::jsonb)) loop
    if exists(select 1 from public.overdraft_accounts where company_id=p_company_id and id=r->>'overdraftId') then
      insert into public.overdraft_transactions(company_id,id,overdraft_id,transaction_date,transaction_type,amount,bank_account_id,description,reference_no,source_type,source_id,status,created_by,created_at)
      values(p_company_id,r->>'id',r->>'overdraftId',coalesce(nullif(r->>'date','')::date,current_date),coalesce(nullif(r->>'transactionType',''),'repayment'),coalesce((r->>'amount')::numeric,0),case when exists(select 1 from public.bank_accounts where company_id=p_company_id and id=r->>'bankAccountId') then r->>'bankAccountId' else null end,r->>'description',r->>'reference',r->>'sourceType',r->>'sourceId',coalesce(nullif(r->>'status',''),'active'),coalesce(public.np_json_uuid(r->>'createdBy'),v_created_by),coalesce((r->>'createdAt')::timestamptz,now()));
    end if;
  end loop;

  for r in select value from jsonb_array_elements(coalesce(j#>'{banking,investmentTransactions}','[]'::jsonb)) loop
    if exists(select 1 from public.bank_accounts where company_id=p_company_id and id=r->>'investmentAccountId') then
      insert into public.investment_transactions(company_id,id,investment_account_id,bank_account_id,transaction_date,transaction_type,quantity,unit_price,total_amount,commission,tax,realized_pnl,current_unit_price,unrealized_pnl,description,reference_no,status,created_by,created_at)
      values(p_company_id,r->>'id',r->>'investmentAccountId',case when exists(select 1 from public.bank_accounts where company_id=p_company_id and id=r->>'bankAccountId') then r->>'bankAccountId' else null end,coalesce(nullif(r->>'date','')::date,current_date),coalesce(nullif(r->>'transactionType',''),'buy'),coalesce((r->>'quantity')::numeric,0),coalesce((r->>'unitPrice')::numeric,0),coalesce((r->>'totalAmount')::numeric,0),coalesce((r->>'commission')::numeric,0),coalesce((r->>'tax')::numeric,0),coalesce((r->>'realizedPnl')::numeric,0),coalesce((r->>'currentUnitPrice')::numeric,0),coalesce((r->>'unrealizedPnl')::numeric,0),r->>'description',r->>'reference',coalesce(nullif(r->>'status',''),'active'),coalesce(public.np_json_uuid(r->>'createdBy'),v_created_by),coalesce((r->>'createdAt')::timestamptz,now()));
    end if;
  end loop;

  for r in select value from jsonb_array_elements(coalesce(j#>'{banking,cardTransactions}','[]'::jsonb)) loop
    if exists(select 1 from public.credit_cards where company_id=p_company_id and id=r->>'cardId') then
      insert into public.credit_card_transactions(company_id,id,card_id,transaction_date,transaction_type,direction,amount,description,source_type,source_id,from_account_id,installment_count,reference_no,status,created_by,created_at)
      values(p_company_id,r->>'id',r->>'cardId',coalesce(nullif(r->>'date','')::date,current_date),coalesce(nullif(r->>'type',''),'manual'),case when r->>'direction'='decrease' then 'decrease' else 'increase' end,coalesce((r->>'amount')::numeric,0),r->>'description',coalesce(nullif(r->>'sourceType',''),'manual'),r->>'sourceId',case when exists(select 1 from public.bank_accounts where company_id=p_company_id and id=r->>'fromAccountId') then r->>'fromAccountId' else null end,coalesce((r->>'installmentCount')::integer,1),r->>'reference',coalesce(nullif(r->>'status',''),'active'),coalesce(public.np_json_uuid(r->>'createdBy'),v_created_by),coalesce((r->>'createdAt')::timestamptz,now()));
    end if;
  end loop;

  -- Eski/yeni kart ödeme kayıtlarını kart hareketlerine dönüştür.
  for r in select value from jsonb_array_elements(coalesce(j->'creditCardPayments','[]'::jsonb)) loop
    if exists(select 1 from public.credit_cards where company_id=p_company_id and id=r->>'cardId') then
      insert into public.credit_card_transactions(company_id,id,card_id,transaction_date,transaction_type,direction,amount,description,source_type,source_id,from_account_id,installment_count,reference_no,status,created_by,created_at)
      values(p_company_id,'payment-'||(r->>'id'),r->>'cardId',coalesce(nullif(r->>'date','')::date,current_date),coalesce(nullif(r->>'paymentType',''),'payment'),'decrease',coalesce((r->>'amount')::numeric,0),r->>'description','credit_card_payment',r->>'id',case when exists(select 1 from public.bank_accounts where company_id=p_company_id and id=r->>'fromAccountId') then r->>'fromAccountId' else null end,1,r->>'reference','active',coalesce(public.np_json_uuid(r->>'createdBy'),v_created_by),coalesce((r->>'createdAt')::timestamptz,now()));
    end if;
  end loop;

  for r in select value from jsonb_array_elements(coalesce(j#>'{banking,cardInstallments}','[]'::jsonb)) loop
    if exists(select 1 from public.credit_cards where company_id=p_company_id and id=r->>'cardId') and exists(select 1 from public.credit_card_transactions where company_id=p_company_id and id=r->>'transactionId') then
      insert into public.credit_card_installments(company_id,id,card_id,transaction_id,installment_no,installment_count,amount,due_month,status,created_at)
      values(p_company_id,r->>'id',r->>'cardId',r->>'transactionId',coalesce((r->>'installmentNo')::integer,1),coalesce((r->>'installmentCount')::integer,1),coalesce((r->>'amount')::numeric,0),coalesce(nullif(r->>'dueMonth',''),to_char(current_date,'YYYY-MM')),coalesce(nullif(r->>'status',''),'planned'),coalesce((r->>'createdAt')::timestamptz,now()));
    end if;
  end loop;

  -- Gelir ve gider ödeme dağılımları. Eski tek ödeme yöntemi kayıtları da taşınır.
  foreach v_parent_type in array array['income','expense'] loop
    for r in select value from jsonb_array_elements(coalesce(j->v_parent_type,'[]'::jsonb)) loop
      v_parent_id:=r->>'id';
      if jsonb_typeof(r->'paymentAllocations')='array' and jsonb_array_length(r->'paymentAllocations')>0 then
        for a in select value from jsonb_array_elements(r->'paymentAllocations') loop
          v_method:=coalesce(nullif(a->>'method',''),'cash');
          insert into public.payment_allocations(company_id,id,parent_type,parent_id,payment_method,bank_account_id,credit_card_id,overdraft_id,amount,account_amount,currency,exchange_rate,created_by,updated_by,created_at,updated_at)
          values(
            p_company_id,
            coalesce(nullif(a->>'id',''),encode(digest(v_parent_type||v_parent_id||v_method||coalesce(a->>'amount','0'),'sha256'),'hex')),
            v_parent_type,v_parent_id,v_method,
            case when v_method like 'bank:%' and exists(select 1 from public.bank_accounts where company_id=p_company_id and id=substring(v_method from 6)) then substring(v_method from 6) else null end,
            case when v_method like 'card:%' and exists(select 1 from public.credit_cards where company_id=p_company_id and id=substring(v_method from 6)) then substring(v_method from 6) else null end,
            case when v_method like 'overdraft:%' and exists(select 1 from public.overdraft_accounts where company_id=p_company_id and id=substring(v_method from 11)) then substring(v_method from 11) else null end,
            greatest(coalesce((a->>'amount')::numeric,0),0.000001),
            greatest(coalesce((coalesce(a->>'accountAmount',a->>'amount'))::numeric,0),0.000001),
            coalesce(nullif(a->>'currency',''),coalesce(nullif(r->>'currency',''),'TRY')),
            coalesce((a->>'rate')::numeric,1),v_created_by,v_created_by,
            coalesce((r->>'createdAt')::timestamptz,now()),coalesce((r->>'updatedAt')::timestamptz,coalesce((r->>'createdAt')::timestamptz,now()))
          );
        end loop;
      else
        v_method:=coalesce(nullif(r->>'paymentAccount',''),'cash');
        insert into public.payment_allocations(company_id,id,parent_type,parent_id,payment_method,bank_account_id,credit_card_id,overdraft_id,amount,account_amount,currency,exchange_rate,created_by,updated_by,created_at,updated_at)
        values(
          p_company_id,'legacy-'||v_parent_type||'-'||v_parent_id,v_parent_type,v_parent_id,v_method,
          case when v_method like 'bank:%' and exists(select 1 from public.bank_accounts where company_id=p_company_id and id=substring(v_method from 6)) then substring(v_method from 6) else null end,
          case when v_method like 'card:%' and exists(select 1 from public.credit_cards where company_id=p_company_id and id=substring(v_method from 6)) then substring(v_method from 6) else null end,
          case when v_method like 'overdraft:%' and exists(select 1 from public.overdraft_accounts where company_id=p_company_id and id=substring(v_method from 11)) then substring(v_method from 11) else null end,
          greatest(coalesce((coalesce(r->>'amountOriginal',r->>'amount'))::numeric,0),0.000001),
          greatest(coalesce((coalesce(r->>'amountOriginal',r->>'amount'))::numeric,0),0.000001),
          coalesce(nullif(r->>'currency',''),'TRY'),coalesce((r->>'rate')::numeric,1),v_created_by,v_created_by,
          coalesce((r->>'createdAt')::timestamptz,now()),coalesce((r->>'updatedAt')::timestamptz,coalesce((r->>'createdAt')::timestamptz,now()))
        );
      end if;
    end loop;
  end loop;

  for r in select value from jsonb_array_elements(coalesce(j#>'{banking,reversals}','[]'::jsonb)) loop
    insert into public.finance_reversals(company_id,id,entity_type,entity_id,snapshot,reason,created_by,created_at)
    values(p_company_id,r->>'id',coalesce(nullif(r->>'entityType',''),'unknown'),coalesce(nullif(r->>'entityId',''),'unknown'),coalesce(r->'snapshot','{}'::jsonb),r->>'reason',coalesce(public.np_json_uuid(r->>'createdBy'),v_created_by),coalesce((r->>'createdAt')::timestamptz,now()));
  end loop;
end;
$$;

create or replace function public.np_company_data_banking_sync_trigger()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  perform public.np_sync_company_banking_snapshot(new.company_id,new.data);
  return new;
end;
$$;

drop trigger if exists trg_company_data_banking_sync on public.company_data;
create trigger trg_company_data_banking_sync
after insert or update of data on public.company_data
for each row execute function public.np_company_data_banking_sync_trigger();

-- Mevcut firma verilerini ilk kurulumda güvenli biçimde aynala.
do $$
declare r record;
begin
  for r in select company_id,data from public.company_data loop
    perform public.np_sync_company_banking_snapshot(r.company_id,r.data);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 6) Bakiye ve net varlık doğrulama görünümleri
-- ---------------------------------------------------------------------------
create or replace view public.v_bank_account_balances
with (security_invoker=true)
as
select
  a.company_id,a.id as account_id,a.institution_id,a.name,a.account_type,a.currency,
  a.opening_balance,
  a.opening_balance+coalesce(sum(case when t.status='active' and t.direction='in' then t.amount when t.status='active' and t.direction='out' then -t.amount else 0 end),0) as calculated_balance,
  a.blocked_amount,
  a.opening_balance+coalesce(sum(case when t.status='active' and t.direction='in' then t.amount when t.status='active' and t.direction='out' then -t.amount else 0 end),0)-a.blocked_amount as available_balance
from public.bank_accounts a
left join public.bank_account_transactions t on t.company_id=a.company_id and t.account_id=a.id
group by a.company_id,a.id,a.institution_id,a.name,a.account_type,a.currency,a.opening_balance,a.blocked_amount;

grant select on public.v_bank_account_balances to authenticated;
grant select,insert,update,delete on public.company_finance_permissions,public.financial_institutions,public.bank_accounts,public.bank_account_transactions,public.credit_cards,public.credit_card_transactions,public.credit_card_installments,public.overdraft_accounts,public.overdraft_transactions,public.investment_accounts,public.term_deposits,public.investment_transactions,public.account_transfers,public.payment_allocations,public.finance_reversals to authenticated;
grant execute on function public.np_has_finance_permission(uuid,text) to authenticated;
grant execute on function public.np_finance_permissions_json(uuid) to authenticated;
grant execute on function public.np_sync_company_banking_snapshot(uuid,jsonb) to service_role;
grant execute on function public.np_has_finance_permission(uuid,text) to authenticated;
grant execute on function public.np_finance_permissions_json(uuid) to authenticated;

commit;
