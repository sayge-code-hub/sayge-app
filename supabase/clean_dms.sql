-- Wipe all DMS metadata (and optional storage objects).
-- Run in Supabase SQL Editor. Does NOT touch employees / clients / invoices.

-- 1) Document rows
delete from public.documents;

-- 2) DMS entity catalog (vendors / candidates / manual company rows)
delete from public.dms_entities;

-- 3) Optional: remove uploaded files from the documents storage bucket
--    (safe if the bucket does not exist — this block is ignored on error)
do $$
begin
  delete from storage.objects
  where bucket_id = 'documents';
exception
  when undefined_table then
    null;
  when others then
    raise notice 'Skipped storage cleanup: %', sqlerrm;
end $$;

-- 4) Add category column for document grouping (idempotent)
alter table public.documents
  add column if not exists category text not null default 'General';
