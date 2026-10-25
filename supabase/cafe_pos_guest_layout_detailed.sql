-- Add Detailed View guest QR layout (safe to re-run).

alter table public.cafes
  drop constraint if exists cafes_guest_layout_check;

alter table public.cafes
  add constraint cafes_guest_layout_check
  check (guest_layout in ('fresh', 'gallery', 'detailed'));

comment on column public.cafes.guest_layout is
  'Guest menu layout: fresh | gallery | detailed.';
