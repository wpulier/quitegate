alter table public.quietgate_devices
  drop constraint if exists quietgate_devices_platform_check;

alter table public.quietgate_devices
  add constraint quietgate_devices_platform_check
  check (
    platform in (
      'macos',
      'ios',
      'web',
      'chrome',
      'chrome_extension',
      'firefox',
      'safari'
    )
  );
