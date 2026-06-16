create or replace function public.current_clerk_user_id()
returns text
language sql
stable
as $$
  select nullif(auth.jwt()->>'sub', '');
$$;

create or replace function public.quietgate_default_policy_v1()
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'schemaVersion', 1,
    'mode', 'focus',
    'adultBlockingEnabled', true,
    'browser', jsonb_build_object(
      'features', jsonb_build_object(
        'youtubeHome', true,
        'youtubeVideoSidebar', false,
        'youtubeRecommendations', false,
        'youtubeLiveChat', false,
        'youtubePlaylists', false,
        'youtubeFundraisers', false,
        'youtubeEndScreens', false,
        'youtubeEndScreenCards', false,
        'youtubeShorts', true,
        'youtubeComments', false,
        'youtubeMixes', false,
        'youtubeMerch', false,
        'youtubeVideoInfo', false,
        'youtubeTopHeader', false,
        'youtubeNotifications', false,
        'youtubeSearch', false,
        'youtubeExplore', false,
        'youtubeMoreFromYouTube', false,
        'youtubeSubscriptions', false,
        'youtubeAutoplay', false,
        'youtubeAnnotations', false,
        'youtubeUsageTracking', true,
        'youtubeDailyLimit', false,
        'xSensitiveMedia', true,
        'xExplicitContent', false,
        'xExplicitSearch', false,
        'xVideos', true,
        'xPhotos', false,
        'xMediaCards', false,
        'xExploreTrends', false,
        'instagramReels', true,
        'instagramExplore', true,
        'instagramSuggested', true,
        'instagramStories', false,
        'redditPopularAll', true,
        'redditRecommendations', true,
        'redditNSFW', false,
        'redditMedia', false,
        'redditSidebars', false
      ),
      'blockedDomains', jsonb_build_array(),
      'blockedCategories', jsonb_build_array('adultContent'),
      'options', jsonb_build_object(
        'explicitHideStyle', 'post',
        'youtubeDailyLimitMinutes', 30
      )
    ),
    'schedules', jsonb_build_object(
      'enabled', false,
      'dailyFocusWindows', jsonb_build_array()
    ),
    'applications', jsonb_build_object(
      'enforcementEnabled', true,
      'blocked', jsonb_build_array(),
      'allowed', jsonb_build_array()
    )
  );
$$;

create table if not exists public.quietgate_users (
  id uuid primary key default gen_random_uuid(),
  clerk_user_id text not null unique,
  primary_email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.quietgate_policies (
  user_id uuid primary key references public.quietgate_users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.quietgate_policies
  add column if not exists policy jsonb,
  add column if not exists settings_version integer not null default 1;

do $$
declare
  has_all_legacy_columns boolean;
begin
  select count(*) = 8
  into has_all_legacy_columns
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'quietgate_policies'
    and column_name in (
      'mode',
      'adult_blocking_enabled',
      'explicit_hide_style',
      'x_tuning',
      'reddit_tuning',
      'youtube_tuning',
      'blocked_domains',
      'version'
    );

  if has_all_legacy_columns then
    execute $legacy$
      update public.quietgate_policies
      set policy = jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              public.quietgate_default_policy_v1(),
              '{mode}',
              to_jsonb(coalesce(mode, 'focus'))
            ),
            '{adultBlockingEnabled}',
            to_jsonb(coalesce(adult_blocking_enabled, true))
          ),
          '{browser,options,explicitHideStyle}',
          to_jsonb(coalesce(explicit_hide_style, 'post'))
        ),
        '{browser,blockedDomains}',
        coalesce(blocked_domains, '[]'::jsonb)
      )
      ||
      jsonb_build_object(
        'browser',
        (
          (public.quietgate_default_policy_v1()->'browser')
          ||
          jsonb_build_object(
            'features',
            (public.quietgate_default_policy_v1()->'browser'->'features')
            ||
            jsonb_build_object(
              'youtubeHome', coalesce((youtube_tuning->>'youtubeHome')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeHome')::boolean)),
              'youtubeVideoSidebar', coalesce((youtube_tuning->>'youtubeVideoSidebar')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeVideoSidebar')::boolean)),
              'youtubeRecommendations', coalesce((youtube_tuning->>'youtubeRecommendations')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeRecommendations')::boolean)),
              'youtubeLiveChat', coalesce((youtube_tuning->>'youtubeLiveChat')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeLiveChat')::boolean)),
              'youtubePlaylists', coalesce((youtube_tuning->>'youtubePlaylists')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubePlaylists')::boolean)),
              'youtubeFundraisers', coalesce((youtube_tuning->>'youtubeFundraisers')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeFundraisers')::boolean)),
              'youtubeEndScreens', coalesce((youtube_tuning->>'youtubeEndScreens')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeEndScreens')::boolean)),
              'youtubeEndScreenCards', coalesce((youtube_tuning->>'youtubeEndScreenCards')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeEndScreenCards')::boolean)),
              'youtubeShorts', coalesce((youtube_tuning->>'youtubeShorts')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeShorts')::boolean)),
              'youtubeComments', coalesce((youtube_tuning->>'youtubeComments')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeComments')::boolean)),
              'youtubeMixes', coalesce((youtube_tuning->>'youtubeMixes')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeMixes')::boolean)),
              'youtubeMerch', coalesce((youtube_tuning->>'youtubeMerch')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeMerch')::boolean)),
              'youtubeVideoInfo', coalesce((youtube_tuning->>'youtubeVideoInfo')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeVideoInfo')::boolean)),
              'youtubeTopHeader', coalesce((youtube_tuning->>'youtubeTopHeader')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeTopHeader')::boolean)),
              'youtubeNotifications', coalesce((youtube_tuning->>'youtubeNotifications')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeNotifications')::boolean)),
              'youtubeSearch', coalesce((youtube_tuning->>'youtubeSearch')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeSearch')::boolean)),
              'youtubeExplore', coalesce((youtube_tuning->>'youtubeExplore')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeExplore')::boolean)),
              'youtubeMoreFromYouTube', coalesce((youtube_tuning->>'youtubeMoreFromYouTube')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeMoreFromYouTube')::boolean)),
              'youtubeSubscriptions', coalesce((youtube_tuning->>'youtubeSubscriptions')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeSubscriptions')::boolean)),
              'youtubeAutoplay', coalesce((youtube_tuning->>'youtubeAutoplay')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeAutoplay')::boolean)),
              'youtubeAnnotations', coalesce((youtube_tuning->>'youtubeAnnotations')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeAnnotations')::boolean)),
              'youtubeUsageTracking', coalesce((youtube_tuning->>'youtubeUsageTracking')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeUsageTracking')::boolean)),
              'youtubeDailyLimit', coalesce((youtube_tuning->>'youtubeDailyLimit')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'youtubeDailyLimit')::boolean)),
              'xSensitiveMedia', coalesce((x_tuning->>'sensitiveMedia')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'xSensitiveMedia')::boolean)),
              'xExplicitContent', coalesce((x_tuning->>'explicitContent')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'xExplicitContent')::boolean)),
              'xExplicitSearch', coalesce((x_tuning->>'explicitSearch')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'xExplicitSearch')::boolean)),
              'xVideos', coalesce((x_tuning->>'videos')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'xVideos')::boolean)),
              'xPhotos', coalesce((x_tuning->>'photos')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'xPhotos')::boolean)),
              'xMediaCards', coalesce((x_tuning->>'cards')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'xMediaCards')::boolean)),
              'xExploreTrends', coalesce((x_tuning->>'exploreTrends')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'xExploreTrends')::boolean)),
              'redditPopularAll', coalesce((reddit_tuning->>'popularAll')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'redditPopularAll')::boolean)),
              'redditRecommendations', coalesce((reddit_tuning->>'recommendations')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'redditRecommendations')::boolean)),
              'redditNSFW', coalesce((reddit_tuning->>'nsfw')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'redditNSFW')::boolean)),
              'redditMedia', coalesce((reddit_tuning->>'media')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'redditMedia')::boolean)),
              'redditSidebars', coalesce((reddit_tuning->>'sidebars')::boolean, ((public.quietgate_default_policy_v1()->'browser'->'features'->>'redditSidebars')::boolean))
            ),
            'blockedDomains',
            coalesce(blocked_domains, '[]'::jsonb),
            'options',
            (public.quietgate_default_policy_v1()->'browser'->'options')
            ||
            jsonb_build_object(
              'explicitHideStyle', coalesce(explicit_hide_style, 'post'),
              'youtubeDailyLimitMinutes',
              coalesce(
                (youtube_tuning->>'youtubeDailyLimitMinutes')::integer,
                ((public.quietgate_default_policy_v1()->'browser'->'options'->>'youtubeDailyLimitMinutes')::integer)
              )
            )
          )
        )
      )
      where policy is null
    $legacy$;
  end if;
end;
$$;

update public.quietgate_policies
set policy = public.quietgate_default_policy_v1()
where policy is null;

alter table public.quietgate_policies
  alter column policy set default public.quietgate_default_policy_v1(),
  alter column policy set not null;

alter table public.quietgate_policies
  drop constraint if exists quietgate_policies_policy_schema_version_check,
  add constraint quietgate_policies_policy_schema_version_check
    check ((policy->>'schemaVersion') = '1'),
  drop constraint if exists quietgate_policies_settings_version_check,
  add constraint quietgate_policies_settings_version_check
    check (settings_version >= 1);

create table if not exists public.quietgate_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.quietgate_users(id) on delete cascade,
  platform text not null,
  name text not null,
  public_key text,
  app_version text,
  helper_version text,
  last_seen_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.quietgate_devices
  add column if not exists installation_id text,
  add column if not exists platform_metadata jsonb not null default '{}'::jsonb;

update public.quietgate_devices
set installation_id = id::text
where installation_id is null;

alter table public.quietgate_devices
  alter column installation_id set not null;

create unique index if not exists quietgate_devices_user_installation_id_idx
  on public.quietgate_devices (user_id, installation_id);

create table if not exists public.quietgate_device_health (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.quietgate_devices(id) on delete cascade,
  app_version text,
  helper_version text,
  ruleset_version text,
  script_versions jsonb not null default '{}'::jsonb,
  canary_status jsonb not null default '{}'::jsonb,
  adult_protection jsonb not null default '{}'::jsonb,
  reported_at timestamptz not null default now()
);

create or replace function public.quietgate_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.quietgate_touch_policy()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  if tg_op = 'UPDATE' then
    new.settings_version = old.settings_version + 1;
  end if;
  return new;
end;
$$;

drop trigger if exists quietgate_policies_set_updated_at on public.quietgate_policies;
drop trigger if exists quietgate_touch_policy on public.quietgate_policies;
create trigger quietgate_touch_policy
before update on public.quietgate_policies
for each row
execute function public.quietgate_touch_policy();

drop trigger if exists quietgate_users_set_updated_at on public.quietgate_users;
drop trigger if exists quietgate_touch_users_updated_at on public.quietgate_users;
create trigger quietgate_touch_users_updated_at
before update on public.quietgate_users
for each row
execute function public.quietgate_touch_updated_at();

drop trigger if exists quietgate_devices_set_updated_at on public.quietgate_devices;
drop trigger if exists quietgate_touch_devices_updated_at on public.quietgate_devices;
create trigger quietgate_touch_devices_updated_at
before update on public.quietgate_devices
for each row
execute function public.quietgate_touch_updated_at();

alter table public.quietgate_policies
  drop column if exists version,
  drop column if exists mode,
  drop column if exists adult_blocking_enabled,
  drop column if exists explicit_hide_style,
  drop column if exists x_tuning,
  drop column if exists reddit_tuning,
  drop column if exists youtube_tuning,
  drop column if exists blocked_domains;

alter table public.quietgate_users enable row level security;
alter table public.quietgate_policies enable row level security;
alter table public.quietgate_devices enable row level security;
alter table public.quietgate_device_health enable row level security;

revoke all on public.quietgate_users from anon;
revoke all on public.quietgate_policies from anon;
revoke all on public.quietgate_devices from anon;
revoke all on public.quietgate_device_health from anon;

grant select, insert, update on public.quietgate_users to authenticated;
grant select, insert, update on public.quietgate_policies to authenticated;
grant select, insert, update on public.quietgate_devices to authenticated;
grant select, insert on public.quietgate_device_health to authenticated;

drop policy if exists clerk_select_own_quietgate_user on public.quietgate_users;
create policy clerk_select_own_quietgate_user
on public.quietgate_users
for select
to authenticated
using (clerk_user_id = public.current_clerk_user_id());

drop policy if exists clerk_insert_own_quietgate_user on public.quietgate_users;
create policy clerk_insert_own_quietgate_user
on public.quietgate_users
for insert
to authenticated
with check (clerk_user_id = public.current_clerk_user_id());

drop policy if exists clerk_update_own_quietgate_user on public.quietgate_users;
create policy clerk_update_own_quietgate_user
on public.quietgate_users
for update
to authenticated
using (clerk_user_id = public.current_clerk_user_id())
with check (clerk_user_id = public.current_clerk_user_id());

drop policy if exists clerk_select_own_quietgate_policy on public.quietgate_policies;
create policy clerk_select_own_quietgate_policy
on public.quietgate_policies
for select
to authenticated
using (
  exists (
    select 1
    from public.quietgate_users qgu
    where qgu.id = quietgate_policies.user_id
      and qgu.clerk_user_id = public.current_clerk_user_id()
  )
);

drop policy if exists clerk_insert_own_quietgate_policy on public.quietgate_policies;
create policy clerk_insert_own_quietgate_policy
on public.quietgate_policies
for insert
to authenticated
with check (
  exists (
    select 1
    from public.quietgate_users qgu
    where qgu.id = quietgate_policies.user_id
      and qgu.clerk_user_id = public.current_clerk_user_id()
  )
);

drop policy if exists clerk_update_own_quietgate_policy on public.quietgate_policies;
create policy clerk_update_own_quietgate_policy
on public.quietgate_policies
for update
to authenticated
using (
  exists (
    select 1
    from public.quietgate_users qgu
    where qgu.id = quietgate_policies.user_id
      and qgu.clerk_user_id = public.current_clerk_user_id()
  )
)
with check (
  exists (
    select 1
    from public.quietgate_users qgu
    where qgu.id = quietgate_policies.user_id
      and qgu.clerk_user_id = public.current_clerk_user_id()
  )
);

drop policy if exists clerk_select_own_quietgate_devices on public.quietgate_devices;
create policy clerk_select_own_quietgate_devices
on public.quietgate_devices
for select
to authenticated
using (
  exists (
    select 1
    from public.quietgate_users qgu
    where qgu.id = quietgate_devices.user_id
      and qgu.clerk_user_id = public.current_clerk_user_id()
  )
);

drop policy if exists clerk_insert_own_quietgate_devices on public.quietgate_devices;
create policy clerk_insert_own_quietgate_devices
on public.quietgate_devices
for insert
to authenticated
with check (
  exists (
    select 1
    from public.quietgate_users qgu
    where qgu.id = quietgate_devices.user_id
      and qgu.clerk_user_id = public.current_clerk_user_id()
  )
);

drop policy if exists clerk_update_own_quietgate_devices on public.quietgate_devices;
create policy clerk_update_own_quietgate_devices
on public.quietgate_devices
for update
to authenticated
using (
  exists (
    select 1
    from public.quietgate_users qgu
    where qgu.id = quietgate_devices.user_id
      and qgu.clerk_user_id = public.current_clerk_user_id()
  )
)
with check (
  exists (
    select 1
    from public.quietgate_users qgu
    where qgu.id = quietgate_devices.user_id
      and qgu.clerk_user_id = public.current_clerk_user_id()
  )
);

drop policy if exists clerk_select_own_quietgate_device_health on public.quietgate_device_health;
create policy clerk_select_own_quietgate_device_health
on public.quietgate_device_health
for select
to authenticated
using (
  exists (
    select 1
    from public.quietgate_devices qgd
    join public.quietgate_users qgu on qgu.id = qgd.user_id
    where qgd.id = quietgate_device_health.device_id
      and qgu.clerk_user_id = public.current_clerk_user_id()
  )
);

drop policy if exists clerk_insert_own_quietgate_device_health on public.quietgate_device_health;
create policy clerk_insert_own_quietgate_device_health
on public.quietgate_device_health
for insert
to authenticated
with check (
  exists (
    select 1
    from public.quietgate_devices qgd
    join public.quietgate_users qgu on qgu.id = qgd.user_id
    where qgd.id = quietgate_device_health.device_id
      and qgd.revoked_at is null
      and qgu.clerk_user_id = public.current_clerk_user_id()
  )
);

revoke all on function public.current_clerk_user_id() from public, anon;
grant execute on function public.current_clerk_user_id() to authenticated, service_role;
revoke all on function public.quietgate_default_policy_v1() from public, anon;
grant execute on function public.quietgate_default_policy_v1() to authenticated, service_role;
revoke all on function public.quietgate_touch_updated_at() from public, anon, authenticated;
revoke all on function public.quietgate_touch_policy() from public, anon, authenticated;

notify pgrst, 'reload schema';
