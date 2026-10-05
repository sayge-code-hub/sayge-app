-- Billing monthly rate used on proposals (distinct from monthly_ctc / payroll).

alter table public.employees
  add column if not exists monthly_rate numeric(14, 2) not null default 0;

update public.employees set monthly_rate = 208333 where employee_id = '2319';
update public.employees set monthly_rate = 91667 where employee_id = '2125';
