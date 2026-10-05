-- Last working day / exit from organisation.
alter table public.employees
  add column if not exists date_of_exit date;
