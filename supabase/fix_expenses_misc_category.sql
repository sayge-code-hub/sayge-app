-- Allow Misc in expenses.category (idempotent).

alter table public.expenses
  drop constraint if exists expenses_category_chk;

alter table public.expenses
  add constraint expenses_category_chk check (
    category in (
      'Software Tools',
      'Commissions',
      'CA',
      'Accountant Consulting',
      'Misc'
    )
  );
