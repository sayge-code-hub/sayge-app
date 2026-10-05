-- Employee phone / contact number on profile.

alter table public.employees
  add column if not exists contact_no text not null default '';
