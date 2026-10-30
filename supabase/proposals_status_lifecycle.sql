-- Proposal statuses: active, sent, accepted, archived,
-- discarded_by_client, discarded_by_us.
-- Run in the Supabase SQL editor (idempotent).

alter table public.proposals
  drop constraint if exists proposals_status_check;

alter table public.proposals
  add constraint proposals_status_check
  check (status in (
    'active',
    'sent',
    'accepted',
    'archived',
    'discarded_by_client',
    'discarded_by_us'
  ));
