-- Optional subtitle on DMS catalog entities (idempotent).
-- Required by createCatalogEntity in the app.

alter table public.dms_entities
  add column if not exists subtitle text not null default '';
