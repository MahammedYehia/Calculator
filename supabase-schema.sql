create extension if not exists pgcrypto;

create table if not exists public.shared_tabs (
  id uuid primary key default gen_random_uuid(),
  join_code text not null unique,
  name_a text not null,
  name_b text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shared_tabs_join_code_format check (join_code = upper(join_code)),
  constraint shared_tabs_names_not_blank check (length(trim(name_a)) > 0 and length(trim(name_b)) > 0)
);

create table if not exists public.expenses (
  id text primary key,
  tab_id uuid not null references public.shared_tabs(id) on delete cascade,
  payer text not null,
  item_desc text not null default '',
  amount numeric(12,2) not null,
  ts bigint not null,
  created_at timestamptz not null default now(),
  constraint expenses_payer_check check (payer in ('a', 'b')),
  constraint expenses_amount_positive check (amount > 0)
);

create index if not exists expenses_tab_id_idx on public.expenses(tab_id);
create index if not exists expenses_tab_id_ts_idx on public.expenses(tab_id, ts desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists shared_tabs_set_updated_at on public.shared_tabs;
create trigger shared_tabs_set_updated_at
before update on public.shared_tabs
for each row
execute function public.set_updated_at();

alter table public.shared_tabs enable row level security;
alter table public.expenses enable row level security;

drop policy if exists "anon can read shared_tabs" on public.shared_tabs;
create policy "anon can read shared_tabs"
on public.shared_tabs
for select
to anon, authenticated
using (true);

drop policy if exists "anon can insert shared_tabs" on public.shared_tabs;
create policy "anon can insert shared_tabs"
on public.shared_tabs
for insert
to anon, authenticated
with check (true);

drop policy if exists "anon can update shared_tabs" on public.shared_tabs;
create policy "anon can update shared_tabs"
on public.shared_tabs
for update
to anon, authenticated
using (true)
with check (true);

drop policy if exists "anon can delete shared_tabs" on public.shared_tabs;
create policy "anon can delete shared_tabs"
on public.shared_tabs
for delete
to anon, authenticated
using (true);

drop policy if exists "anon can read expenses" on public.expenses;
create policy "anon can read expenses"
on public.expenses
for select
to anon, authenticated
using (true);

drop policy if exists "anon can insert expenses" on public.expenses;
create policy "anon can insert expenses"
on public.expenses
for insert
to anon, authenticated
with check (true);

drop policy if exists "anon can update expenses" on public.expenses;
create policy "anon can update expenses"
on public.expenses
for update
to anon, authenticated
using (true)
with check (true);

drop policy if exists "anon can delete expenses" on public.expenses;
create policy "anon can delete expenses"
on public.expenses
for delete
to anon, authenticated
using (true);
