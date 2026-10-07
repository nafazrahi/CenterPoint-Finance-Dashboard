-- Recurring income sources + automatic monthly expectation generation.
-- Run after the consolidated database and property-management migrations.

create table if not exists public.recurring_income_sources (
  id uuid primary key default gen_random_uuid(),
  property_id uuid references public.properties(id) on delete set null,
  category_id uuid not null references public.categories(id) on delete restrict,
  source_name text not null,
  monthly_amount numeric(14,2) not null check (monthly_amount > 0),
  start_month date not null,
  end_month date,
  active boolean not null default true,
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (date_trunc('month', start_month)::date = start_month),
  check (end_month is null or (date_trunc('month', end_month)::date = end_month and end_month >= start_month))
);

alter table public.expected_income
  add column if not exists recurring_income_source_id uuid references public.recurring_income_sources(id) on delete set null;

create index if not exists idx_recurring_income_active_month
  on public.recurring_income_sources(active, start_month, end_month);
create index if not exists idx_recurring_income_property
  on public.recurring_income_sources(property_id);
create index if not exists idx_expected_income_recurring_source
  on public.expected_income(recurring_income_source_id, period_month);

create unique index if not exists uq_expected_income_recurring_month
  on public.expected_income(recurring_income_source_id, period_month)
  where recurring_income_source_id is not null;

alter table public.recurring_income_sources enable row level security;

drop policy if exists recurring_income_select on public.recurring_income_sources;
drop policy if exists recurring_income_admin_insert on public.recurring_income_sources;
drop policy if exists recurring_income_admin_update on public.recurring_income_sources;
drop policy if exists recurring_income_admin_delete on public.recurring_income_sources;

create policy recurring_income_select on public.recurring_income_sources
for select to authenticated using (true);

create policy recurring_income_admin_insert on public.recurring_income_sources
for insert to authenticated
with check (public.get_my_role() = 'admin');

create policy recurring_income_admin_update on public.recurring_income_sources
for update to authenticated
using (public.get_my_role() = 'admin')
with check (public.get_my_role() = 'admin');

create policy recurring_income_admin_delete on public.recurring_income_sources
for delete to authenticated
using (public.get_my_role() = 'admin');

-- Generate missing monthly expectations. Past expectations are never changed by this function.
create or replace function public.generate_monthly_expected_income(p_month date)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_month date := date_trunc('month', p_month)::date;
  v_count integer := 0;
begin
  if public.get_my_role() not in ('admin','manager') then
    raise exception 'not authorized';
  end if;

  insert into public.expected_income (
    property_id, category_id, source_name, expected_amount, period_month,
    due_date, status, notes, created_by, recurring_income_source_id
  )
  select
    r.property_id,
    r.category_id,
    r.source_name,
    r.monthly_amount,
    v_month,
    v_month + 14,
    'pending',
    r.notes,
    auth.uid(),
    r.id
  from public.recurring_income_sources r
  where r.active = true
    and r.start_month <= v_month
    and (r.end_month is null or r.end_month >= v_month)
    and not exists (
      select 1 from public.expected_income e
      where e.recurring_income_source_id = r.id
        and e.period_month = v_month
    )
    and (r.property_id is null or exists (
      select 1 from public.properties p where p.id = r.property_id and p.active = true
    ));

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.generate_monthly_expected_income(date) from public, anon;
grant execute on function public.generate_monthly_expected_income(date) to authenticated;

-- Admin-only permanent deletion for financial records.
drop policy if exists expected_income_admin_delete on public.expected_income;
create policy expected_income_admin_delete on public.expected_income
for delete to authenticated using (public.get_my_role() = 'admin');

drop policy if exists income_admin_delete on public.income_transactions;
create policy income_admin_delete on public.income_transactions
for delete to authenticated using (public.get_my_role() = 'admin');

drop policy if exists expense_admin_delete on public.expense_transactions;
create policy expense_admin_delete on public.expense_transactions
for delete to authenticated using (public.get_my_role() = 'admin');

-- Keep updated_at correct for recurring sources.
drop trigger if exists trg_recurring_income_updated_at on public.recurring_income_sources;
create trigger trg_recurring_income_updated_at
before update on public.recurring_income_sources
for each row execute function public.set_updated_at();
