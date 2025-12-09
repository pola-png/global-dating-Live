-- Wallet + verification/boost fields on users
alter table public.users
  add column if not exists coin_balance integer not null default 0,
  add column if not exists is_boosted boolean not null default false,
  add column if not exists boosted_until timestamptz,
  add column if not exists is_verified boolean not null default false;

-- Live streams directory
create table if not exists public.live_streams (
  id uuid primary key default gen_random_uuid(),
  title text,
  host_id uuid references auth.users (id) on delete set null,
  host_name text,
  viewer_count integer not null default 0,
  is_live boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists live_streams_created_at_idx on public.live_streams(created_at desc);
create index if not exists live_streams_host_id_idx on public.live_streams(host_id);

alter table public.live_streams enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'live_read' and tablename = 'live_streams') then
    create policy "live_read" on public.live_streams
      for select using (true);
  end if;

  if not exists (select 1 from pg_policies where policyname = 'live_insert' and tablename = 'live_streams') then
    create policy "live_insert" on public.live_streams
      for insert with check (auth.uid() = host_id);
  end if;

  if not exists (select 1 from pg_policies where policyname = 'live_update_host' and tablename = 'live_streams') then
    create policy "live_update_host" on public.live_streams
      for update using (auth.uid() = host_id);
  end if;
end $$;
