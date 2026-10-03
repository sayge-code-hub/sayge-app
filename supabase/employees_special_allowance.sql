-- Fixed special allowance on employee master (carved from gross before Basic/HRA).
alter table public.employees
  add column if not exists special_allowance numeric(14, 2) not null default 0;

-- Akshat Srivastava (2126) — fixed monthly net ₹36,528 with PF.
-- Monthly CTC = Gross + Employer PF + Retention.
update public.employees
set
  pf_applicable = true,
  retention_amount = 2000,
  special_allowance = 0,
  monthly_ctc = 48226,
  annual_ctc = 578712,
  tds_amount = 0
where employee_id = '2126';

-- Praful Dohatare (2125) — fixed monthly net ₹45,138 with PF.
-- Monthly CTC = Gross + Employer PF + Retention.
update public.employees
set
  pf_applicable = true,
  retention_amount = 2000,
  special_allowance = 0,
  monthly_ctc = 58334,
  annual_ctc = 700008,
  tds_amount = 0
where employee_id = '2125';
