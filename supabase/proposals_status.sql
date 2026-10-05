-- Proposal lifecycle status for list UI + bulk download filtering.
-- active = included in "Download all"; archived is skipped.

alter table public.proposals
  add column if not exists status text not null default 'active';

update public.proposals
set status = 'archived'
where status in ('voided', 'rejected', 'null');

alter table public.proposals
  drop constraint if exists proposals_status_check;

alter table public.proposals
  add constraint proposals_status_check
  check (status in ('active', 'archived'));

create index if not exists proposals_status_idx
  on public.proposals (status);
