create table if not exists public.quietgate_extension_link_codes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.quietgate_users(id) on delete cascade,
  code_hash text not null unique,
  nonce_hash text not null,
  extension_id text not null,
  installation_id text not null,
  extension_version text,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists quietgate_extension_link_codes_user_idx
  on public.quietgate_extension_link_codes (user_id, created_at desc);

create index if not exists quietgate_extension_link_codes_expires_idx
  on public.quietgate_extension_link_codes (expires_at)
  where consumed_at is null;

create table if not exists public.quietgate_device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.quietgate_users(id) on delete cascade,
  device_id uuid not null references public.quietgate_devices(id) on delete cascade,
  token_hash text not null unique,
  token_prefix text not null,
  scopes text[] not null default array['policy:read', 'health:write', 'device:revoke'],
  last_used_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists quietgate_device_tokens_device_idx
  on public.quietgate_device_tokens (device_id, created_at desc);

create index if not exists quietgate_device_tokens_active_hash_idx
  on public.quietgate_device_tokens (token_hash)
  where revoked_at is null;

alter table public.quietgate_device_health
  add column if not exists platform_metadata jsonb not null default '{}'::jsonb,
  add column if not exists enabled_permissions jsonb not null default '{}'::jsonb,
  add column if not exists recent_block_counters jsonb not null default '{}'::jsonb,
  add column if not exists last_sync_at timestamptz;

drop trigger if exists quietgate_touch_device_tokens_updated_at on public.quietgate_device_tokens;
create trigger quietgate_touch_device_tokens_updated_at
before update on public.quietgate_device_tokens
for each row
execute function public.quietgate_touch_updated_at();

alter table public.quietgate_extension_link_codes enable row level security;
alter table public.quietgate_device_tokens enable row level security;

revoke all on public.quietgate_extension_link_codes from public, anon, authenticated;
revoke all on public.quietgate_device_tokens from public, anon, authenticated;

notify pgrst, 'reload schema';
