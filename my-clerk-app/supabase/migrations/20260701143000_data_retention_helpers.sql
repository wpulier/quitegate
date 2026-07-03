create or replace function public.quietgate_prune_retained_data(
  usage_retention_days integer default 180,
  health_retention_days integer default 45
)
returns table (
  deleted_site_usage bigint,
  deleted_device_health bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  usage_deleted bigint := 0;
  health_deleted bigint := 0;
begin
  delete from public.quietgate_site_usage
  where usage_date < (current_date - greatest(usage_retention_days, 1));
  get diagnostics usage_deleted = row_count;

  delete from public.quietgate_device_health
  where reported_at < (now() - make_interval(days => greatest(health_retention_days, 1)));
  get diagnostics health_deleted = row_count;

  return query select usage_deleted, health_deleted;
end;
$$;

revoke all on function public.quietgate_prune_retained_data(integer, integer) from public, anon, authenticated;

notify pgrst, 'reload schema';
