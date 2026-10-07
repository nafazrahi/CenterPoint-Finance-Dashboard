-- Phase 6: expense cancellation / void support
-- Run after 001_initial_schema.sql and 002_rls_auth_audit.sql.

alter table public.expense_transactions
  add column if not exists status text not null default 'active'
  check (status in ('active', 'voided'));

alter table public.expense_transactions
  add column if not exists voided_at timestamptz;

alter table public.expense_transactions
  add column if not exists void_reason text;

create index if not exists idx_expense_status on public.expense_transactions(status);

create or replace view public.monthly_financial_summary as
select
  m.month_start,
  coalesce(i.total_income, 0)::numeric(14,2) as total_income,
  coalesce(e.total_expense, 0)::numeric(14,2) as total_expense,
  (coalesce(i.total_income, 0) - coalesce(e.total_expense, 0))::numeric(14,2) as net_cash_flow
from (
  select distinct date_trunc('month', transaction_date)::date as month_start
  from public.income_transactions
  union
  select distinct date_trunc('month', transaction_date)::date as month_start
  from public.expense_transactions
) m
left join (
  select date_trunc('month', transaction_date)::date as month_start,
         sum(amount) as total_income
  from public.income_transactions
  group by 1
) i using (month_start)
left join (
  select date_trunc('month', transaction_date)::date as month_start,
         sum(amount) as total_expense
  from public.expense_transactions
  where status = 'active'
  group by 1
) e using (month_start);

-- The existing audit trigger already captures inserts and updates.
drop trigger if exists trg_expense_audit on public.expense_transactions;
create trigger trg_expense_audit
after insert or update on public.expense_transactions
for each row execute function public.audit_financial_change();
