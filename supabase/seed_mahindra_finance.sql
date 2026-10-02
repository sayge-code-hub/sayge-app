-- Mahindra Finance contacts (from MMFSL proposal PDF).
-- Multiple rows allowed for the same company with different contacts.
-- Run after clients columns + clients_name_key drop are applied.

alter table public.clients drop constraint if exists clients_name_key;

insert into public.clients (
  id,
  name,
  vendor_code,
  entity_code,
  contact_name,
  address,
  gstin
) values
  (
    'mahindra-finance-ketan-jain',
    'Mahindra Finance',
    'VC10062792',
    '2438335',
    'Mr. Ketan Jain',
    E'Mahindra & Mahindra Financial Services Ltd.\nMahindra Towers, Dr. G.M. Bhosale Marg,\nP.K. Kurne Chowk,\nWorli\nMumbai\n400018 Maharashtra\nIndia',
    '27AAACM2931R2Z2'
  ),
  (
    'mahindra-finance-jaspreet-lamba',
    'Mahindra Finance',
    'VC10062792',
    '2438335',
    'Ms. Jaspreet Lamba',
    E'Mahindra & Mahindra Financial Services Ltd.\nMahindra Towers, Dr. G.M. Bhosale Marg,\nP.K. Kurne Chowk,\nWorli\nMumbai\n400018 Maharashtra\nIndia',
    '27AAACM2931R2Z2'
  )
on conflict (id) do update set
  name = excluded.name,
  vendor_code = excluded.vendor_code,
  entity_code = excluded.entity_code,
  contact_name = excluded.contact_name,
  address = excluded.address,
  gstin = excluded.gstin;
