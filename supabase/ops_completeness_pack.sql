-- Ops completeness pack: invoice payments, expense date/receipts,
-- payroll runs, employee self-service RLS, DMS entity helpers.
-- Run in Supabase SQL Editor (idempotent).

-- ---------------------------------------------------------------------------
-- Invoices: payment tracking
-- ---------------------------------------------------------------------------
alter table public.invoices
  add column if not exists payment_status text not null default 'unpaid'
    check (payment_status in ('unpaid', 'partial', 'paid', 'overdue')),
  add column if not exists amount_paid numeric(14, 2) not null default 0,
  add column if not exists due_date date,
  add column if not exists paid_at date;

create index if not exists invoices_payment_status_idx
  on public.invoices (payment_status);

create index if not exists invoices_due_date_idx
  on public.invoices (due_date);

-- ---------------------------------------------------------------------------
-- Expenses: business date + receipt attachment
-- ---------------------------------------------------------------------------
alter table public.expenses
  add column if not exists expense_date date,
  add column if not exists receipt_path text,
  add column if not exists receipt_name text;

update public.expenses
set expense_date = coalesce(expense_date, (created_at at time zone 'utc')::date)
where expense_date is null;

alter table public.expenses
  alter column expense_date set default (current_date);

-- Pending expenses: creator or staff may update (edit pending / attach receipt).
drop policy if exists "expenses_update_rbac" on public.expenses;
create policy "expenses_update_rbac"
  on public.expenses for update
  to authenticated
  using (
    public.app_is_staff()
    or (
      created_by = auth.uid()
      and approval_status = 'pending'
    )
  )
  with check (
    public.app_is_staff()
    or (
      created_by = auth.uid()
      and approval_status = 'pending'
    )
  );

-- ---------------------------------------------------------------------------
-- Payroll runs (persist generated slips)
-- ---------------------------------------------------------------------------
create table if not exists public.payroll_runs (
  id text primary key,
  period_year int not null,
  period_month int not null,
  generated_at timestamptz not null default now(),
  generated_by uuid references auth.users (id) on delete set null,
  employee_count int not null default 0,
  notes text not null default '',
  unique (period_year, period_month)
);

create table if not exists public.payslip_records (
  id text primary key,
  payroll_run_id text not null references public.payroll_runs (id) on delete cascade,
  employee_id text not null,
  employee_name text not null default '',
  period_year int not null,
  period_month int not null,
  gross_earnings numeric(14, 2) not null default 0,
  total_deductions numeric(14, 2) not null default 0,
  net_pay numeric(14, 2) not null default 0,
  snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists payslip_records_run_idx
  on public.payslip_records (payroll_run_id);
create index if not exists payslip_records_employee_idx
  on public.payslip_records (employee_id, period_year, period_month);

alter table public.payroll_runs enable row level security;
alter table public.payslip_records enable row level security;

drop policy if exists "payroll_runs_select_rbac" on public.payroll_runs;
drop policy if exists "payroll_runs_write_rbac" on public.payroll_runs;
drop policy if exists "payslip_records_select_rbac" on public.payslip_records;
drop policy if exists "payslip_records_write_rbac" on public.payslip_records;

create policy "payroll_runs_select_rbac"
  on public.payroll_runs for select to authenticated
  using (public.app_is_staff());
create policy "payroll_runs_write_rbac"
  on public.payroll_runs for all to authenticated
  using (public.app_is_staff())
  with check (public.app_is_staff());

create policy "payslip_records_select_rbac"
  on public.payslip_records for select to authenticated
  using (
    public.app_is_staff()
    or employee_id = public.app_employee_id()
  );
create policy "payslip_records_write_rbac"
  on public.payslip_records for all to authenticated
  using (public.app_is_staff())
  with check (public.app_is_staff());

grant select, insert, update, delete on public.payroll_runs to authenticated;
grant select, insert, update, delete on public.payslip_records to authenticated;

-- ---------------------------------------------------------------------------
-- Employees: self-update limited contact fields
-- ---------------------------------------------------------------------------
create or replace function public.employee_self_update_guard()
returns trigger
language plpgsql
as $$
begin
  if public.app_is_staff() then
    return new;
  end if;
  if old.employee_id is distinct from public.app_employee_id() then
    raise exception 'Employees may only update their own profile';
  end if;
  -- Allow only contact / address style fields to change for self-service.
  if new.employee_name is distinct from old.employee_name
     or new.date_of_joining is distinct from old.date_of_joining
     or new.designation is distinct from old.designation
     or new.department is distinct from old.department
     or new.annual_ctc is distinct from old.annual_ctc
     or new.monthly_ctc is distinct from old.monthly_ctc
     or new.monthly_rate is distinct from old.monthly_rate
     or new.client_id is distinct from old.client_id
     or new.is_active is distinct from old.is_active
     or new.is_draft is distinct from old.is_draft
     or new.date_of_exit is distinct from old.date_of_exit
     or new.grade is distinct from old.grade
     or new.bank_account is distinct from old.bank_account
     or new.ifsc is distinct from old.ifsc
     or new.pan is distinct from old.pan
     or new.uan is distinct from old.uan
  then
    raise exception 'Employees may only update contact details';
  end if;
  return new;
end;
$$;

drop trigger if exists employees_self_update_guard on public.employees;
create trigger employees_self_update_guard
  before update on public.employees
  for each row execute function public.employee_self_update_guard();

drop policy if exists "employees_update_rbac" on public.employees;
create policy "employees_update_rbac"
  on public.employees for update
  to authenticated
  using (
    public.app_is_staff()
    or employee_id = public.app_employee_id()
  )
  with check (
    public.app_is_staff()
    or employee_id = public.app_employee_id()
  );

-- Documents: employees may insert/delete own attachments
drop policy if exists "documents_insert_rbac" on public.documents;
drop policy if exists "documents_delete_rbac" on public.documents;
drop policy if exists "documents_update_rbac" on public.documents;

create policy "documents_insert_rbac"
  on public.documents for insert
  to authenticated
  with check (
    public.app_is_staff()
    or (
      entity_type = 'employee'
      and entity_id = public.app_employee_id()
    )
  );

create policy "documents_update_rbac"
  on public.documents for update
  to authenticated
  using (
    public.app_is_staff()
    or (
      entity_type = 'employee'
      and entity_id = public.app_employee_id()
    )
  )
  with check (
    public.app_is_staff()
    or (
      entity_type = 'employee'
      and entity_id = public.app_employee_id()
    )
  );

create policy "documents_delete_rbac"
  on public.documents for delete
  to authenticated
  using (
    public.app_is_staff()
    or (
      entity_type = 'employee'
      and entity_id = public.app_employee_id()
    )
  );

-- Expense receipts live in documents bucket under expenses/
insert into storage.buckets (id, name, public)
values ('documents', 'documents', true)
on conflict (id) do update set public = excluded.public;
