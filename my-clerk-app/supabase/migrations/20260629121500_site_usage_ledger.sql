create table if not exists public.quietgate_site_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.quietgate_users(id) on delete cascade,
  device_id uuid not null references public.quietgate_devices(id) on delete cascade,
  site_id text not null,
  usage_date date not null,
  total_seconds integer not null default 0,
  lifetime_seconds integer not null default 0,
  activity_count integer,
  lifetime_activity_count integer,
  activity_label text,
  limit_seconds integer,
  limit_reached boolean not null default false,
  source_type text not null default 'web',
  source_id text not null,
  source_label text,
  browser_id text,
  browser_name text,
  profile_id text,
  profile_name text,
  device_name text,
  platform_metadata jsonb not null default '{}'::jsonb,
  last_usage_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint quietgate_site_usage_site_id_check
    check (site_id in ('youtube', 'x', 'instagram', 'reddit')),
  constraint quietgate_site_usage_total_seconds_check
    check (total_seconds >= 0),
  constraint quietgate_site_usage_lifetime_seconds_check
    check (lifetime_seconds >= 0),
  constraint quietgate_site_usage_activity_count_check
    check (activity_count is null or activity_count >= 0),
  constraint quietgate_site_usage_lifetime_activity_count_check
    check (lifetime_activity_count is null or lifetime_activity_count >= 0),
  constraint quietgate_site_usage_limit_seconds_check
    check (limit_seconds is null or limit_seconds >= 0)
);

create unique index if not exists quietgate_site_usage_source_day_idx
  on public.quietgate_site_usage (user_id, site_id, usage_date, source_id);

create index if not exists quietgate_site_usage_user_day_idx
  on public.quietgate_site_usage (user_id, usage_date desc, updated_at desc);

drop trigger if exists quietgate_touch_site_usage_updated_at on public.quietgate_site_usage;
create trigger quietgate_touch_site_usage_updated_at
before update on public.quietgate_site_usage
for each row
execute function public.quietgate_touch_updated_at();

alter table public.quietgate_site_usage enable row level security;

revoke all on public.quietgate_site_usage from public, anon;
grant select, insert, update on public.quietgate_site_usage to authenticated;

drop policy if exists clerk_select_own_quietgate_site_usage on public.quietgate_site_usage;
create policy clerk_select_own_quietgate_site_usage
on public.quietgate_site_usage
for select
to authenticated
using (
  exists (
    select 1
    from public.quietgate_users qgu
    where qgu.id = quietgate_site_usage.user_id
      and qgu.clerk_user_id = public.current_clerk_user_id()
  )
);

drop policy if exists clerk_insert_own_quietgate_site_usage on public.quietgate_site_usage;
create policy clerk_insert_own_quietgate_site_usage
on public.quietgate_site_usage
for insert
to authenticated
with check (
  exists (
    select 1
    from public.quietgate_users qgu
    join public.quietgate_devices qgd on qgd.user_id = qgu.id
    where qgu.id = quietgate_site_usage.user_id
      and qgd.id = quietgate_site_usage.device_id
      and qgu.clerk_user_id = public.current_clerk_user_id()
  )
);

drop policy if exists clerk_update_own_quietgate_site_usage on public.quietgate_site_usage;
create policy clerk_update_own_quietgate_site_usage
on public.quietgate_site_usage
for update
to authenticated
using (
  exists (
    select 1
    from public.quietgate_users qgu
    where qgu.id = quietgate_site_usage.user_id
      and qgu.clerk_user_id = public.current_clerk_user_id()
  )
)
with check (
  exists (
    select 1
    from public.quietgate_users qgu
    join public.quietgate_devices qgd on qgd.user_id = qgu.id
    where qgu.id = quietgate_site_usage.user_id
      and qgd.id = quietgate_site_usage.device_id
      and qgu.clerk_user_id = public.current_clerk_user_id()
  )
);

notify pgrst, 'reload schema';
