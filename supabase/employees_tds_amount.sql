-- Monthly TDS on employee master (used by payslip calculator).
alter table public.employees
  add column if not exists tds_amount numeric(14, 2) not null default 0;

update public.employees
set tds_amount = 19549
where employee_id = '2319' and tds_amount = 0;
