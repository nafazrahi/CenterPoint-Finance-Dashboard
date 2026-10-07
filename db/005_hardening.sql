-- Optional hardening migration for the rebuilt app.
-- The core consolidated schema can be used without this migration.

-- Keep recurring expectations easy to find.
create index if not exists idx_expected_income_period_property
  on public.expected_income(period_month, property_id);

create index if not exists idx_income_expected_id
  on public.income_transactions(expected_income_id);

create index if not exists idx_income_transaction_date
  on public.income_transactions(transaction_date);

create index if not exists idx_expense_transaction_date
  on public.expense_transactions(transaction_date);
