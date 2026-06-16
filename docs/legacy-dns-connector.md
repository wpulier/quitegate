# Legacy provider Connector

Older QuietGate builds used NextDNS as the primary system-blocking control
plane. That connector is now legacy-only. Keep the code isolated for migration
and experiments, but do not design normal onboarding around a DNS account, setup
code, profile ID, or API key.

The default app runtime clears stale legacy provider defaults from old installs and
always uses disabled legacy provider services. Launching the public app cannot
reactivate this connector with an environment variable or saved default.

Developers can exercise the old connector only by constructing
`ProtectionStore.makeLegacyProviderRuntimeStore()` from test or developer-only
code. Do not wire that factory into normal app startup.

The old local defaults flag is intentionally ignored and removed during normal
startup so a public build cannot accidentally fall back into DNS-account
onboarding.

Older builds also included a local `/etc/hosts` fallback. It is no longer a
normal product path.
