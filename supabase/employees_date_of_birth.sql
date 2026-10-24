-- Date of birth on employees (idempotent).
-- Required by EmployeeModel.toJson / HR create-edit forms.

alter table public.employees
  add column if not exists date_of_birth date;
