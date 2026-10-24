-- Cafe billing / GST display settings on cafes (safe to re-run).

alter table public.cafes
  add column if not exists show_gst_on_bill boolean not null default true;

alter table public.cafes
  add column if not exists gst_label text not null default 'GST';

alter table public.cafes
  add column if not exists gst_split_halves boolean not null default false;

comment on column public.cafes.show_gst_on_bill is
  'When true, terminal bill shows GST lines (from item tax rates).';
comment on column public.cafes.gst_label is
  'Label for tax on the bill, e.g. GST.';
comment on column public.cafes.gst_split_halves is
  'When true, split tax equally into CGST + SGST on the bill.';
