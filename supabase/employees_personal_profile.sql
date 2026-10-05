-- Personal profile fields from new-joiners form.

alter table public.employees
  add column if not exists residential_address text not null default '',
  add column if not exists alternate_contact text not null default '',
  add column if not exists personal_email text not null default '',
  add column if not exists gender text not null default '',
  add column if not exists father_name text not null default '',
  add column if not exists mother_name text not null default '',
  add column if not exists nationality text not null default '',
  add column if not exists pincode text not null default '';

alter table public.documents
  add column if not exists category text not null default 'General';
