-- Superseded by expense_categories.sql.
-- Drop the fixed category list so Settings can manage categories.

alter table public.expenses
  drop constraint if exists expenses_category_chk;
