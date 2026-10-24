-- Dine-in table support (safe to re-run).

-- How many numbered tables the terminal shows for this cafe.
alter table public.cafes
  add column if not exists table_count integer not null default 16;

alter table public.cafes
  drop constraint if exists cafes_table_count_check;

alter table public.cafes
  add constraint cafes_table_count_check
  check (table_count >= 1 and table_count <= 100);

comment on column public.cafes.table_count is
  'Number of dine-in tables shown on the POS terminal (1–100).';

-- Table number on orders (empty for takeaway).
alter table public.cafe_orders
  add column if not exists table_no text not null default '';

comment on column public.cafe_orders.table_no is
  'Dine-in table number; empty string for takeaway / unset.';
