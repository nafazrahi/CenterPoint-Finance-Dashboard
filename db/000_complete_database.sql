-- BUILDING FINANCE APP - COMPLETE SUPABASE DATABASE SETUP
-- Paste this entire file into Supabase SQL Editor and click RUN.

create extension if not exists pgcrypto;

-- ============================================================
-- 1. TYPES
-- ============================================================
do $$ begin
  create type public.user_role as enum ('admin','manager','viewer');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.property_type as enum ('apartment','shop','other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.category_type as enum ('income','expense');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.payment_method as enum ('cash','bank','bkash','nagad','other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.expected_income_status as enum ('pending','partially_received','received','cancelled');
exception when duplicate_object then null; end $$;

-- ============================================================
-- 2. TABLES
-- ============================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role public.user_role not null default 'viewer',
  preferred_language text not null default 'en' check (preferred_language in ('bn','en')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.buildings (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  building_id uuid references public.buildings(id) on delete set null,
  name text not null,
  property_type public.property_type not null default 'apartment',
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name_bn text not null,
  name_en text not null,
  category_type public.category_type not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.expected_income (
  id uuid primary key default gen_random_uuid(),
  property_id uuid references public.properties(id) on delete set null,
  category_id uuid references public.categories(id) on delete set null,
  source_name text not null,
  expected_amount numeric(14,2) not null check (expected_amount >= 0),
  period_month date not null,
  due_date date,
  status public.expected_income_status not null default 'pending',
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.income_transactions (
  id uuid primary key default gen_random_uuid(),
  transaction_date date not null default current_date,
  amount numeric(14,2) not null check (amount > 0),
  category_id uuid references public.categories(id) on delete set null,
  property_id uuid references public.properties(id) on delete set null,
  source_name text,
  payment_method public.payment_method not null default 'cash',
  expected_income_id uuid references public.expected_income(id) on delete set null,
  note text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.expense_transactions (
  id uuid primary key default gen_random_uuid(),
  transaction_date date not null default current_date,
  amount numeric(14,2) not null check (amount > 0),
  category_id uuid references public.categories(id) on delete set null,
  property_id uuid references public.properties(id) on delete set null,
  payee text,
  payment_method public.payment_method not null default 'cash',
  note text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.attachments (
  id uuid primary key default gen_random_uuid(),
  income_transaction_id uuid references public.income_transactions(id) on delete cascade,
  expense_transaction_id uuid references public.expense_transactions(id) on delete cascade,
  storage_path text not null,
  original_file_name text not null,
  mime_type text,
  file_size_bytes bigint,
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint attachments_one_parent check (
    (income_transaction_id is not null and expense_transaction_id is null)
    or (income_transaction_id is null and expense_transaction_id is not null)
  )
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  table_name text not null,
  record_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

-- Phase 6: expense voiding
alter table public.expense_transactions
  add column if not exists status text not null default 'active';

alter table public.expense_transactions
  add column if not exists voided_at timestamptz;

alter table public.expense_transactions
  add column if not exists void_reason text;

-- Phase 8: property management
alter table public.properties
  add column if not exists monthly_rent numeric(14,2) not null default 0 check (monthly_rent >= 0);

alter table public.properties
  add column if not exists monthly_service_charge numeric(14,2) not null default 0 check (monthly_service_charge >= 0);

alter table public.properties
  add column if not exists occupied boolean not null default false;

alter table public.properties
  add column if not exists occupant_name text;

-- ============================================================
-- 3. INDEXES
-- ============================================================
create index if not exists idx_properties_building on public.properties(building_id);
create index if not exists idx_properties_occupied on public.properties(occupied);
create index if not exists idx_expected_income_month on public.expected_income(period_month);
create index if not exists idx_expected_income_status on public.expected_income(status);
create index if not exists idx_income_date on public.income_transactions(transaction_date);
create index if not exists idx_income_expected on public.income_transactions(expected_income_id);
create index if not exists idx_expense_date on public.expense_transactions(transaction_date);
create index if not exists idx_expense_status on public.expense_transactions(status);
create index if not exists idx_attachments_income on public.attachments(income_transaction_id);
create index if not exists idx_attachments_expense on public.attachments(expense_transaction_id);
create index if not exists idx_audit_created on public.audit_logs(created_at);

-- ============================================================
-- 4. UPDATED_AT FUNCTION + TRIGGERS
-- ============================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_buildings_updated_at on public.buildings;
create trigger trg_buildings_updated_at before update on public.buildings
for each row execute function public.set_updated_at();

drop trigger if exists trg_properties_updated_at on public.properties;
create trigger trg_properties_updated_at before update on public.properties
for each row execute function public.set_updated_at();

drop trigger if exists trg_categories_updated_at on public.categories;
create trigger trg_categories_updated_at before update on public.categories
for each row execute function public.set_updated_at();

drop trigger if exists trg_expected_income_updated_at on public.expected_income;
create trigger trg_expected_income_updated_at before update on public.expected_income
for each row execute function public.set_updated_at();

drop trigger if exists trg_income_updated_at on public.income_transactions;
create trigger trg_income_updated_at before update on public.income_transactions
for each row execute function public.set_updated_at();

drop trigger if exists trg_expense_updated_at on public.expense_transactions;
create trigger trg_expense_updated_at before update on public.expense_transactions
for each row execute function public.set_updated_at();

-- ============================================================
-- 5. STARTER CATEGORIES
-- ============================================================
insert into public.categories (name_bn,name_en,category_type,sort_order)
select 'ফ্ল্যাট ভাড়া','Apartment Rent','income',10
where not exists (select 1 from public.categories where name_en='Apartment Rent' and category_type='income');

insert into public.categories (name_bn,name_en,category_type,sort_order)
select 'দোকান ভাড়া','Shop Rent','income',20
where not exists (select 1 from public.categories where name_en='Shop Rent' and category_type='income');

insert into public.categories (name_bn,name_en,category_type,sort_order)
select 'সার্ভিস চার্জ','Service Charge','income',30
where not exists (select 1 from public.categories where name_en='Service Charge' and category_type='income');

insert into public.categories (name_bn,name_en,category_type,sort_order)
select 'ভাড়া অগ্রিম','Rent Advance','income',40
where not exists (select 1 from public.categories where name_en='Rent Advance' and category_type='income');

insert into public.categories (name_bn,name_en,category_type,sort_order)
select 'অন্যান্য আয়','Other Income','income',50
where not exists (select 1 from public.categories where name_en='Other Income' and category_type='income');

insert into public.categories (name_bn,name_en,category_type,sort_order)
select 'বিদ্যুৎ','Electricity','expense',10
where not exists (select 1 from public.categories where name_en='Electricity' and category_type='expense');

insert into public.categories (name_bn,name_en,category_type,sort_order)
select 'গ্যাস','Gas','expense',20
where not exists (select 1 from public.categories where name_en='Gas' and category_type='expense');

insert into public.categories (name_bn,name_en,category_type,sort_order)
select 'Boss','Boss','expense',30
where not exists (select 1 from public.categories where name_en='Boss' and category_type='expense');

insert into public.categories (name_bn,name_en,category_type,sort_order)
select 'মামলা খরচ','Court Case','expense',40
where not exists (select 1 from public.categories where name_en='Court Case' and category_type='expense');

insert into public.categories (name_bn,name_en,category_type,sort_order)
select 'নির্মাণ শ্রমিক','Construction Workers','expense',50
where not exists (select 1 from public.categories where name_en='Construction Workers' and category_type='expense');

insert into public.categories (name_bn,name_en,category_type,sort_order)
select 'বিবিধ','Miscellaneous','expense',60
where not exists (select 1 from public.categories where name_en='Miscellaneous' and category_type='expense');

-- ============================================================
-- 6. MONTHLY SUMMARY VIEW
-- ============================================================
create or replace view public.monthly_financial_summary as
select
  date_trunc('month', m.month_start)::date as month,
  coalesce(i.total_income,0)::numeric(14,2) as total_income,
  coalesce(e.total_expense,0)::numeric(14,2) as total_expense,
  (coalesce(i.total_income,0) - coalesce(e.total_expense,0))::numeric(14,2) as net_cash_flow
from generate_series(
  date_trunc('month', current_date) - interval '11 months',
  date_trunc('month', current_date),
  interval '1 month'
) m(month_start)
left join (
  select date_trunc('month', transaction_date) month_start, sum(amount) total_income
  from public.income_transactions
  group by 1
) i on i.month_start = m.month_start
left join (
  select date_trunc('month', transaction_date) month_start, sum(amount) total_expense
  from public.expense_transactions
  where status = 'active'
  group by 1
) e on e.month_start = m.month_start;

create or replace view public.property_monthly_charge_summary as
select
  p.id,
  p.building_id,
  b.name as building_name,
  p.name as property_name,
  p.property_type,
  p.active,
  p.occupied,
  p.occupant_name,
  p.monthly_rent,
  p.monthly_service_charge,
  (p.monthly_rent + p.monthly_service_charge)::numeric(14,2) as monthly_total
from public.properties p
left join public.buildings b on b.id = p.building_id;

-- ============================================================
-- 7. AUTH PROFILE SETUP
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, preferred_language)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    coalesce(new.raw_user_meta_data->>'preferred_language','en')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.get_my_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid() and active = true;
$$;

-- ============================================================
-- 8. AUDIT LOGGING
-- ============================================================
create or replace function public.audit_financial_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.audit_logs(actor_id,action,table_name,record_id,old_data,new_data)
  values (
    auth.uid(),
    tg_op,
    tg_table_name,
    coalesce(new.id,old.id),
    case when tg_op='INSERT' then null else to_jsonb(old) end,
    case when tg_op='DELETE' then null else to_jsonb(new) end
  );
  return coalesce(new,old);
end;
$$;

drop trigger if exists trg_audit_expected_income on public.expected_income;
create trigger trg_audit_expected_income
after insert or update or delete on public.expected_income
for each row execute function public.audit_financial_change();

drop trigger if exists trg_audit_income on public.income_transactions;
create trigger trg_audit_income
after insert or update or delete on public.income_transactions
for each row execute function public.audit_financial_change();

drop trigger if exists trg_audit_expense on public.expense_transactions;
create trigger trg_audit_expense
after insert or update or delete on public.expense_transactions
for each row execute function public.audit_financial_change();

-- ============================================================
-- 9. ROW LEVEL SECURITY
-- ============================================================
alter table public.profiles enable row level security;
alter table public.buildings enable row level security;
alter table public.properties enable row level security;
alter table public.categories enable row level security;
alter table public.expected_income enable row level security;
alter table public.income_transactions enable row level security;
alter table public.expense_transactions enable row level security;
alter table public.attachments enable row level security;
alter table public.audit_logs enable row level security;

-- Remove policies created by an earlier attempt so this script can be rerun.
do $$ declare r record; begin
  for r in select schemaname, tablename, policyname from pg_policies where schemaname='public' and tablename in ('profiles','buildings','properties','categories','expected_income','income_transactions','expense_transactions','attachments','audit_logs') loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- Profiles
create policy profiles_select on public.profiles
for select to authenticated
using (id = auth.uid() or public.get_my_role() = 'admin');

create policy profiles_admin_update on public.profiles
for update to authenticated
using (public.get_my_role() = 'admin')
with check (public.get_my_role() = 'admin');

-- Reference data: everyone authenticated can read; admin can write.
create policy buildings_select on public.buildings
for select to authenticated using (true);
create policy buildings_admin_insert on public.buildings
for insert to authenticated with check (public.get_my_role() = 'admin');
create policy buildings_admin_update on public.buildings
for update to authenticated using (public.get_my_role() = 'admin') with check (public.get_my_role() = 'admin');

create policy properties_select on public.properties
for select to authenticated using (true);
create policy properties_admin_insert on public.properties
for insert to authenticated with check (public.get_my_role() = 'admin');
create policy properties_admin_update on public.properties
for update to authenticated using (public.get_my_role() = 'admin') with check (public.get_my_role() = 'admin');

create policy categories_select on public.categories
for select to authenticated using (true);
create policy categories_admin_insert on public.categories
for insert to authenticated with check (public.get_my_role() = 'admin');
create policy categories_admin_update on public.categories
for update to authenticated using (public.get_my_role() = 'admin') with check (public.get_my_role() = 'admin');

-- Expected income
create policy expected_income_select on public.expected_income
for select to authenticated using (true);
create policy expected_income_insert on public.expected_income
for insert to authenticated
with check (public.get_my_role() in ('admin','manager'));
create policy expected_income_update on public.expected_income
for update to authenticated
using (public.get_my_role() in ('admin','manager'))
with check (public.get_my_role() in ('admin','manager'));

-- Actual income
create policy income_select on public.income_transactions
for select to authenticated using (true);
create policy income_insert on public.income_transactions
for insert to authenticated
with check (public.get_my_role() in ('admin','manager'));
create policy income_update on public.income_transactions
for update to authenticated
using (public.get_my_role() in ('admin','manager'))
with check (public.get_my_role() in ('admin','manager'));

-- Expenses
create policy expense_select on public.expense_transactions
for select to authenticated using (true);
create policy expense_insert on public.expense_transactions
for insert to authenticated
with check (public.get_my_role() in ('admin','manager'));
create policy expense_update on public.expense_transactions
for update to authenticated
using (public.get_my_role() in ('admin','manager'))
with check (public.get_my_role() in ('admin','manager'));

-- Attachments metadata
create policy attachments_select on public.attachments
for select to authenticated using (true);
create policy attachments_insert on public.attachments
for insert to authenticated
with check (public.get_my_role() in ('admin','manager'));

-- Audit logs: authenticated users can read; only database triggers should write.
create policy audit_logs_select on public.audit_logs
for select to authenticated using (true);

-- ============================================================
-- 10. RECEIPTS STORAGE BUCKET + STORAGE POLICIES
-- ============================================================
insert into storage.buckets (id,name,public)
values ('receipts','receipts',false)
on conflict (id) do update set public=false;

drop policy if exists receipts_read on storage.objects;
drop policy if exists receipts_upload on storage.objects;
drop policy if exists receipts_delete on storage.objects;

do $$ begin
  create policy receipts_read on storage.objects
  for select to authenticated
  using (bucket_id='receipts');
exception when duplicate_object then null; end $$;

do $$ begin
  create policy receipts_upload on storage.objects
  for insert to authenticated
  with check (bucket_id='receipts' and public.get_my_role() in ('admin','manager'));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy receipts_delete on storage.objects
  for delete to authenticated
  using (bucket_id='receipts' and public.get_my_role()='admin');
exception when duplicate_object then null; end $$;

-- ============================================================
-- DONE
-- ============================================================
-- IMPORTANT: After creating your first Supabase Auth user, promote it:
-- update public.profiles
-- set role='admin'
-- where id=(select id from auth.users where email='YOUR_EMAIL_HERE');
