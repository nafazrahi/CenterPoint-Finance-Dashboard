-- Phase 8: property/building management fields
-- Run after 001_initial_schema.sql, 002_rls_auth_audit.sql and 003_expense_void.sql.

alter table public.properties
  add column if not exists monthly_rent numeric(14,2) not null default 0 check (monthly_rent >= 0),
  add column if not exists monthly_service_charge numeric(14,2) not null default 0 check (monthly_service_charge >= 0),
  add column if not exists occupied boolean not null default false,
  add column if not exists occupant_name text;

create index if not exists idx_properties_occupied on public.properties(occupied);

-- Helpful view for admins/managers: current recurring amount configured for each unit.
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
