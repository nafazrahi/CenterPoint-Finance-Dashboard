export type AppRole = 'admin' | 'manager' | 'viewer'
export type Language = 'bn' | 'en'
export interface Profile { id:string; full_name:string; role:AppRole; preferred_language:Language; active:boolean }
export interface Category { id:string; name_bn:string; name_en:string; category_type:'income'|'expense'; active:boolean; sort_order:number }
export interface Property { id:string; building_id:string|null; name:string; property_type:'apartment'|'shop'|'other'; active:boolean; monthly_rent?:number; monthly_service_charge?:number; occupied?:boolean; occupant_name?:string|null; notes?:string|null }
export interface IncomeTransaction { id:string; transaction_date:string; amount:number; category_id:string; property_id:string|null; source_name:string; payment_method:'cash'|'bank'|'bkash'|'nagad'|'other'; expected_income_id:string|null; note:string|null; created_at:string }
export type ExpectedIncomeStatus='pending'|'partially_received'|'received'|'cancelled'
export interface RecurringIncomeSource { id:string; property_id:string|null; category_id:string; source_name:string; monthly_amount:number; start_month:string; end_month:string|null; active:boolean; notes:string|null; created_by:string|null; created_at:string; updated_at:string }
export interface ExpectedIncome { id:string; property_id:string|null; category_id:string; source_name:string; expected_amount:number; period_month:string; due_date:string|null; status:ExpectedIncomeStatus; notes:string|null; created_by:string|null; recurring_income_source_id?:string|null; created_at:string; updated_at:string }
export type ExpenseStatus='active'|'voided'
export interface ExpenseTransaction { id:string; transaction_date:string; amount:number; category_id:string; property_id:string|null; payee:string|null; payment_method:'cash'|'bank'|'bkash'|'nagad'|'other'; note:string|null; status:ExpenseStatus; voided_at:string|null; void_reason:string|null; created_at:string }
