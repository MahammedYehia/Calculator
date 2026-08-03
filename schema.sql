-- مصاريف البيت — schema مستقل عن حساب الأكل
create extension if not exists pgcrypto;

create table if not exists public.household_tabs (
  id uuid primary key default gen_random_uuid(),
  join_code text not null unique,
  name_husband text not null,
  name_wife text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint household_tabs_join_code_format check (join_code = upper(join_code)),
  constraint household_tabs_names_not_blank check (
    length(trim(name_husband)) > 0 and length(trim(name_wife)) > 0
  )
);

create table if not exists public.household_transfers (
  id text primary key,
  tab_id uuid not null references public.household_tabs(id) on delete cascade,
  amount numeric(12,2) not null,
  note text not null default '',
  ts bigint not null,
  deleted_at timestamptz null,
  created_at timestamptz not null default now(),
  constraint household_transfers_amount_positive check (amount > 0)
);

create index if not exists household_transfers_tab_id_idx
  on public.household_transfers(tab_id);
create index if not exists household_transfers_tab_id_ts_idx
  on public.household_transfers(tab_id, ts desc);
create index if not exists household_transfers_tab_id_deleted_at_idx
  on public.household_transfers(tab_id, deleted_at);

create table if not exists public.household_recurring (
  id text primary key,
  tab_id uuid not null references public.household_tabs(id) on delete cascade,
  title text not null,
  category text not null,
  amount numeric(12,2) not null,
  interval_months int not null,
  next_due date not null,
  active boolean not null default true,
  deleted_at timestamptz null,
  created_at timestamptz not null default now(),
  constraint household_recurring_amount_positive check (amount > 0),
  constraint household_recurring_interval_positive check (interval_months > 0),
  constraint household_recurring_title_not_blank check (length(trim(title)) > 0)
);

create index if not exists household_recurring_tab_id_idx
  on public.household_recurring(tab_id);
create index if not exists household_recurring_tab_id_next_due_idx
  on public.household_recurring(tab_id, next_due);
create index if not exists household_recurring_tab_id_deleted_at_idx
  on public.household_recurring(tab_id, deleted_at);

create table if not exists public.household_spends (
  id text primary key,
  tab_id uuid not null references public.household_tabs(id) on delete cascade,
  category text not null,
  item_desc text not null default '',
  amount numeric(12,2) not null,
  ts bigint not null,
  recurring_id text null references public.household_recurring(id) on delete set null,
  deleted_at timestamptz null,
  created_at timestamptz not null default now(),
  constraint household_spends_amount_positive check (amount > 0)
);

create index if not exists household_spends_tab_id_idx
  on public.household_spends(tab_id);
create index if not exists household_spends_tab_id_ts_idx
  on public.household_spends(tab_id, ts desc);
create index if not exists household_spends_tab_id_deleted_at_idx
  on public.household_spends(tab_id, deleted_at);
create index if not exists household_spends_recurring_id_idx
  on public.household_spends(recurring_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists household_tabs_set_updated_at on public.household_tabs;
create trigger household_tabs_set_updated_at
before update on public.household_tabs
for each row
execute function public.set_updated_at();

alter table public.household_tabs enable row level security;
alter table public.household_transfers enable row level security;
alter table public.household_spends enable row level security;
alter table public.household_recurring enable row level security;

-- Open anon policies (join-code secrecy only), matching حساب الأكل style
do $$
declare
  t text;
  ops text[] := array['select','insert','update','delete'];
  op text;
begin
  foreach t in array array[
    'household_tabs',
    'household_transfers',
    'household_spends',
    'household_recurring'
  ]
  loop
    foreach op in array ops
    loop
      execute format('drop policy if exists "anon can %s %s" on public.%I', op, t, t);
      if op = 'select' then
        execute format(
          'create policy "anon can %s %s" on public.%I for select to anon, authenticated using (true)',
          op, t, t
        );
      elsif op = 'insert' then
        execute format(
          'create policy "anon can %s %s" on public.%I for insert to anon, authenticated with check (true)',
          op, t, t
        );
      elsif op = 'update' then
        execute format(
          'create policy "anon can %s %s" on public.%I for update to anon, authenticated using (true) with check (true)',
          op, t, t
        );
      else
        execute format(
          'create policy "anon can %s %s" on public.%I for delete to anon, authenticated using (true)',
          op, t, t
        );
      end if;
    end loop;
  end loop;
end $$;

do $$
begin
  begin
    alter publication supabase_realtime add table public.household_tabs;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.household_transfers;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.household_spends;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.household_recurring;
  exception when duplicate_object then null;
  end;
end $$;
