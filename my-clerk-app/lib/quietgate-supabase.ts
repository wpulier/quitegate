import "server-only";

import {
  defaultQuietGatePolicy,
  parsePolicy,
  type PolicyEnvelope,
  type QuietGatePolicy,
} from "@/lib/policy-contract";
import {
  createClerkSupabaseClient,
  hasSupabasePublicConfig,
} from "@/lib/supabase-clerk";
import {
  createSupabaseAdminClient,
  hasSupabaseAdminConfig,
} from "@/lib/supabase-admin";
import {
  currentQuietGateIdentity,
  type QuietGateIdentity,
} from "@/lib/quietgate-auth";
import type {
  DeviceHealthRequest,
  DeviceRegistrationRequest,
} from "@/lib/device-contract";
import {
  supportedUsageSiteIDs,
  type SiteUsageReportRequest,
  type SiteUsageValue,
  type UsageSiteID,
} from "@/lib/site-usage-contract";

export type QuietGateUserRow = {
  id: string;
  clerk_user_id: string;
  primary_email: string | null;
  created_at?: string;
  updated_at?: string;
};

export type QuietGateAccount = {
  user: QuietGateUserRow;
  policy: PolicyEnvelope;
};

type PolicyRow = {
  policy: unknown;
  settings_version: number;
  updated_at: string;
};

type SiteUsageRow = {
  id: string;
  user_id: string;
  device_id: string;
  site_id: UsageSiteID;
  usage_date: string;
  total_seconds: number;
  lifetime_seconds: number;
  activity_count: number | null;
  lifetime_activity_count: number | null;
  activity_label: string | null;
  limit_seconds: number | null;
  limit_reached: boolean;
  source_type: string;
  source_id: string;
  source_label: string | null;
  browser_id: string | null;
  browser_name: string | null;
  profile_id: string | null;
  profile_name: string | null;
  device_name: string | null;
  platform_metadata: Record<string, unknown>;
  last_usage_at: string | null;
  created_at?: string;
  updated_at?: string;
};

export class PolicyVersionConflictError extends Error {
  latest: PolicyEnvelope;

  constructor(latest: PolicyEnvelope) {
    super("Policy settings version conflict.");
    this.name = "PolicyVersionConflictError";
    this.latest = latest;
  }
}

type QuietGateSupabaseClient = Awaited<
  ReturnType<typeof createClerkSupabaseClient>
>;

export function hasQuietGateDataConfig() {
  return hasSupabaseAdminConfig() || hasSupabasePublicConfig();
}

export async function currentClerkIdentity(request?: Request) {
  return currentQuietGateIdentity(request);
}

async function createQuietGateDataClient(identity?: QuietGateIdentity) {
  if (hasSupabaseAdminConfig()) {
    return createSupabaseAdminClient();
  }

  if (identity?.source === "bearer") {
    throw new Error("Supabase server configuration is not set.");
  }

  return createClerkSupabaseClient();
}

function toPolicyEnvelope(row: PolicyRow): PolicyEnvelope {
  if (typeof row.settings_version !== "number") {
    throw new Error("QuietGate policy row is missing settings_version.");
  }

  if (typeof row.updated_at !== "string") {
    throw new Error("QuietGate policy row is missing updated_at.");
  }

  return {
    policy: parsePolicy(row.policy),
    settingsVersion: row.settings_version,
    updatedAt: row.updated_at,
  };
}

async function selectPolicyEnvelope(
  supabase: QuietGateSupabaseClient,
  userId: string,
) {
  const { data, error } = await supabase
    .from("quietgate_policies")
    .select("policy, settings_version, updated_at")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  return data ? toPolicyEnvelope(data as PolicyRow) : null;
}

function localDateKey(date = new Date()) {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/New_York",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  return formatter.format(date);
}

function usageSiteTitle(siteID: UsageSiteID) {
  switch (siteID) {
    case "youtube":
      return "YouTube";
    case "x":
      return "X";
    case "instagram":
      return "Instagram";
    case "reddit":
      return "Reddit";
  }
}

function defaultActivityLabel(siteID: UsageSiteID) {
  return siteID === "youtube" ? "videos" : null;
}

function nonNegativeInt(value: unknown) {
  return Math.max(Math.floor(Number(value) || 0), 0);
}

function nullableNonNegativeInt(value: unknown) {
  if (value == null || value === "") {
    return null;
  }
  return nonNegativeInt(value);
}

function platformFromDevice(device: Record<string, unknown>) {
  return typeof device.platform === "string" ? device.platform : null;
}

function sourceTypeFromDevice(device: Record<string, unknown>) {
  const platform = platformFromDevice(device);
  if (platform === "ios") {
    return "ios";
  }
  if (platform === "macos") {
    return "macos";
  }
  if (platform === "chrome_extension" || platform === "chrome" || platform === "firefox" || platform === "safari") {
    return "browser";
  }
  return platform || "web";
}

function sourceMetadata(
  device: Record<string, unknown>,
  input: SiteUsageReportRequest,
) {
  const source = input.source ?? {};
  const fallbackType = sourceTypeFromDevice(device);
  const sourceType = source.sourceType || fallbackType;
  const sourceID = source.sourceID || `${sourceType}:${device.id}`;
  const deviceName =
    source.deviceName ||
    (typeof device.name === "string" ? device.name : null) ||
    (sourceType === "ios" ? "iPhone" : "Web browser");
  const browserName =
    source.browserName ||
    (sourceType === "browser" && platformFromDevice(device) === "chrome_extension" ? "Chrome" : null);
  const label =
    source.label ||
    source.profileName ||
    deviceName ||
    (sourceType === "ios" ? "iOS" : "Web browser");

  return {
    sourceType,
    sourceID,
    label,
    browserID: source.browserID,
    browserName,
    profileID: source.profileID,
    profileName: source.profileName,
    deviceName,
    platformMetadata: source.platformMetadata ?? {},
  };
}

function rowActivityCount(siteID: UsageSiteID, usage: SiteUsageValue) {
  if (siteID === "youtube") {
    return nullableNonNegativeInt(usage.activityCount ?? usage.videoCount);
  }
  return usage.activityLabel ? nullableNonNegativeInt(usage.activityCount) : null;
}

function rowLifetimeActivityCount(siteID: UsageSiteID, usage: SiteUsageValue) {
  if (siteID === "youtube") {
    return nullableNonNegativeInt(
      usage.lifetimeActivityCount ?? usage.lifetimeVideoCount,
    );
  }
  return usage.activityLabel
    ? nullableNonNegativeInt(usage.lifetimeActivityCount)
    : null;
}

function siteUsageEntry(row: SiteUsageRow) {
  const activityCount = row.activity_count ?? undefined;
  const lifetimeActivityCount = row.lifetime_activity_count ?? undefined;
  const lastUpdatedAt = row.last_usage_at || row.updated_at || null;

  return {
    id: row.id,
    siteID: row.site_id,
    siteTitle: usageSiteTitle(row.site_id),
    sourceID: row.source_id,
    sourceType: row.source_type,
    browserID: row.browser_id,
    browserName: row.browser_name,
    profileID: row.profile_id,
    profileName: row.profile_name,
    label: row.source_label,
    deviceName: row.device_name,
    date: row.usage_date,
    totalSeconds: row.total_seconds,
    lifetimeSeconds: row.lifetime_seconds,
    activityCount,
    lifetimeActivityCount,
    activityLabel: row.activity_label,
    videoCount: row.site_id === "youtube" ? activityCount ?? 0 : undefined,
    lifetimeVideoCount:
      row.site_id === "youtube" ? lifetimeActivityCount ?? 0 : undefined,
    limitSeconds: row.limit_seconds,
    limitReached: row.limit_reached,
    lastUpdatedAt,
    lastSeenAt: row.updated_at || lastUpdatedAt,
    siteUsage: {
      siteID: row.site_id,
      title: usageSiteTitle(row.site_id),
      date: row.usage_date,
      totalSeconds: row.total_seconds,
      lifetimeSeconds: row.lifetime_seconds,
      activityCount,
      lifetimeActivityCount,
      activityLabel: row.activity_label,
      videoCount: row.site_id === "youtube" ? activityCount ?? 0 : undefined,
      lifetimeVideoCount:
        row.site_id === "youtube" ? lifetimeActivityCount ?? 0 : undefined,
      limitSeconds: row.limit_seconds,
      limitReached: row.limit_reached,
      lastUpdatedAt,
    },
  };
}

function latestLifetimeRows(rows: SiteUsageRow[]) {
  const rowsBySource = new Map<string, SiteUsageRow>();
  for (const row of rows) {
    const key = `${row.site_id}:${row.source_id}`;
    const existing = rowsBySource.get(key);
    const rowTime = Date.parse(row.last_usage_at || row.updated_at || "");
    const existingTime = Date.parse(existing?.last_usage_at || existing?.updated_at || "");
    if (!existing || rowTime >= existingTime) {
      rowsBySource.set(key, row);
    }
  }
  return Array.from(rowsBySource.values());
}

function sumNullable(values: Array<number | null | undefined>) {
  let hasValue = false;
  let total = 0;
  for (const value of values) {
    if (typeof value === "number") {
      hasValue = true;
      total += value;
    }
  }
  return hasValue ? total : null;
}

function siteUsageSummaryFromRows(rows: SiteUsageRow[], date: string) {
  const currentRows = rows.filter((row) => row.usage_date === date);
  const lifetimeRows = latestLifetimeRows(rows);
  const sites = supportedUsageSiteIDs.flatMap((siteID) => {
    const siteRows = currentRows.filter((row) => row.site_id === siteID);
    if (siteRows.length === 0) {
      return [];
    }

    const siteLifetimeRows = lifetimeRows.filter((row) => row.site_id === siteID);
    const entries = siteRows
      .map(siteUsageEntry)
      .sort((lhs, rhs) => rhs.totalSeconds - lhs.totalSeconds);
    const activityCount = sumNullable(siteRows.map((row) => row.activity_count));
    const lifetimeActivityCount = sumNullable(
      siteLifetimeRows.map((row) => row.lifetime_activity_count),
    );
    const lastUpdatedAt = entries
      .map((entry) => entry.lastUpdatedAt)
      .filter((value): value is string => Boolean(value))
      .sort()
      .at(-1) ?? null;

    return [
      {
        siteID,
        title: usageSiteTitle(siteID),
        date,
        totalSeconds: siteRows.reduce((sum, row) => sum + row.total_seconds, 0),
        lifetimeSeconds: siteLifetimeRows.reduce(
          (sum, row) => sum + row.lifetime_seconds,
          0,
        ),
        activityCount,
        lifetimeActivityCount,
        activityLabel: siteRows.find((row) => row.activity_label)?.activity_label ?? defaultActivityLabel(siteID),
        videoCount: siteID === "youtube" ? activityCount ?? 0 : undefined,
        lifetimeVideoCount:
          siteID === "youtube" ? lifetimeActivityCount ?? 0 : undefined,
        limitSeconds: siteRows.find((row) => row.limit_seconds != null)?.limit_seconds ?? null,
        limitReached: siteRows.some((row) => row.limit_reached),
        lastUpdatedAt,
        entries,
      },
    ];
  });

  const allEntries = currentRows
    .map(siteUsageEntry)
    .sort((lhs, rhs) => rhs.totalSeconds - lhs.totalSeconds);
  const totalActivityCount = sumNullable(currentRows.map((row) => row.activity_count));
  const totalLifetimeActivityCount = sumNullable(
    lifetimeRows.map((row) => row.lifetime_activity_count),
  );
  const lastUpdatedAt = allEntries
    .map((entry) => entry.lastUpdatedAt)
    .filter((value): value is string => Boolean(value))
    .sort()
    .at(-1) ?? null;

  return {
    schemaVersion: 1,
    date,
    totalSeconds: currentRows.reduce((sum, row) => sum + row.total_seconds, 0),
    lifetimeSeconds: lifetimeRows.reduce(
      (sum, row) => sum + row.lifetime_seconds,
      0,
    ),
    activityCount: totalActivityCount,
    lifetimeActivityCount: totalLifetimeActivityCount,
    lastUpdatedAt,
    sites,
    entries: allEntries,
  };
}

export async function ensureQuietGateAccount(
  primaryEmail?: string | null,
  identity?: QuietGateIdentity | null,
) {
  const clerkUser = identity ?? (await currentClerkIdentity());

  if (!clerkUser) {
    throw new Error("Unauthorized");
  }

  const supabase = await createQuietGateDataClient(clerkUser);
  const email = primaryEmail ?? clerkUser.email ?? null;
  const { data: existingUser, error: existingUserError } = await supabase
    .from("quietgate_users")
    .select("id, clerk_user_id, primary_email, created_at, updated_at")
    .eq("clerk_user_id", clerkUser.userId)
    .maybeSingle();

  if (existingUserError) {
    throw new Error(existingUserError.message);
  }

  let user = existingUser as QuietGateUserRow | null;

  if (!user) {
    const { data: insertedUser, error: insertUserError } = await supabase
      .from("quietgate_users")
      .insert({
        clerk_user_id: clerkUser.userId,
        primary_email: email,
      })
      .select("id, clerk_user_id, primary_email, created_at, updated_at")
      .single();

    if (insertUserError) {
      throw new Error(insertUserError.message);
    }

    user = insertedUser as QuietGateUserRow;
  } else if (email && user.primary_email !== email) {
    const { data: updatedUser, error: updateUserError } = await supabase
      .from("quietgate_users")
      .update({ primary_email: email })
      .eq("id", user.id)
      .select("id, clerk_user_id, primary_email, created_at, updated_at")
      .single();

    if (updateUserError) {
      throw new Error(updateUserError.message);
    }

    user = updatedUser as QuietGateUserRow;
  }

  let policy = await selectPolicyEnvelope(supabase, user.id);

  if (!policy) {
    const { data: insertedPolicy, error: insertPolicyError } = await supabase
      .from("quietgate_policies")
      .insert({
        user_id: user.id,
        policy: defaultQuietGatePolicy(),
      })
      .select("policy, settings_version, updated_at")
      .single();

    if (insertPolicyError) {
      throw new Error(insertPolicyError.message);
    }

    policy = toPolicyEnvelope(insertedPolicy as PolicyRow);
  }

  return { user, policy } satisfies QuietGateAccount;
}

export async function getQuietGatePolicy(identity?: QuietGateIdentity | null) {
  const account = await ensureQuietGateAccount(null, identity);
  return account.policy;
}

export async function updateQuietGatePolicy(
  expectedSettingsVersion: number,
  policy: QuietGatePolicy,
  identity?: QuietGateIdentity | null,
) {
  const account = await ensureQuietGateAccount(null, identity);
  const supabase = await createQuietGateDataClient(identity ?? undefined);
  const normalizedPolicy = parsePolicy(policy);
  const { data, error } = await supabase
    .from("quietgate_policies")
    .update({ policy: normalizedPolicy })
    .eq("user_id", account.user.id)
    .eq("settings_version", expectedSettingsVersion)
    .select("policy, settings_version, updated_at")
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  if (!data) {
    const latest = await selectPolicyEnvelope(supabase, account.user.id);

    if (!latest) {
      throw new Error("QuietGate policy record was not found.");
    }

    throw new PolicyVersionConflictError(latest);
  }

  return toPolicyEnvelope(data as PolicyRow);
}

export async function listQuietGateDevices(identity?: QuietGateIdentity | null) {
  const account = await ensureQuietGateAccount(null, identity);
  const supabase = await createQuietGateDataClient(identity ?? undefined);
  const { data, error } = await supabase
    .from("quietgate_devices")
    .select("*")
    .eq("user_id", account.user.id)
    .is("revoked_at", null)
    .order("last_seen_at", { ascending: false, nullsFirst: false })
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error(error.message);
  }

  const devices = (data ?? []) as Array<Record<string, unknown>>;
  const deviceIds = devices
    .map((device) => device.id)
    .filter((id): id is string => typeof id === "string");

  if (deviceIds.length === 0) {
    return devices;
  }

  const { data: healthRows, error: healthError } = await supabase
    .from("quietgate_device_health")
    .select(
      "id, device_id, reported_at, app_version, helper_version, ruleset_version, script_versions, canary_status, adult_protection, platform_metadata",
    )
    .in("device_id", deviceIds)
    .order("reported_at", { ascending: false });

  if (healthError) {
    throw new Error(healthError.message);
  }

  const latestHealthByDevice = new Map<string, Record<string, unknown>>();
  for (const health of (healthRows ?? []) as Array<Record<string, unknown>>) {
    const deviceId = health.device_id;
    if (typeof deviceId === "string" && !latestHealthByDevice.has(deviceId)) {
      latestHealthByDevice.set(deviceId, health);
    }
  }

  return devices.map((device) => ({
    ...device,
    latest_health:
      typeof device.id === "string" ? latestHealthByDevice.get(device.id) ?? null : null,
  }));
}

export async function countQuietGateDevices(identity?: QuietGateIdentity | null) {
  const account = await ensureQuietGateAccount(null, identity);
  const supabase = await createQuietGateDataClient(identity ?? undefined);
  const { count, error } = await supabase
    .from("quietgate_devices")
    .select("id", { count: "exact", head: true })
    .eq("user_id", account.user.id)
    .is("revoked_at", null);

  if (error) {
    throw new Error(error.message);
  }

  return count ?? 0;
}

export async function registerQuietGateDevice(
  input: DeviceRegistrationRequest,
  identity?: QuietGateIdentity | null,
) {
  const account = await ensureQuietGateAccount(null, identity);
  const now = new Date().toISOString();
  const payload = {
    user_id: account.user.id,
    installation_id: input.installationId,
    platform: input.platform,
    name: input.name,
    public_key: input.publicKey ?? null,
    app_version: input.appVersion ?? null,
    helper_version: input.helperVersion ?? null,
    platform_metadata: input.platformMetadata,
    last_seen_at: now,
    revoked_at: null,
  };

  const supabase = await createQuietGateDataClient(identity ?? undefined);
  const { data, error } = await supabase
    .from("quietgate_devices")
    .upsert(payload, { onConflict: "user_id,installation_id" })
    .select("*")
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as Record<string, unknown>;
}

export async function recordQuietGateDeviceHealth(
  deviceId: string,
  input: DeviceHealthRequest,
  identity?: QuietGateIdentity | null,
) {
  const account = await ensureQuietGateAccount(null, identity);
  const supabase = await createQuietGateDataClient(identity ?? undefined);
  const { data: device, error: deviceError } = await supabase
    .from("quietgate_devices")
    .update({
      app_version: input.appVersion ?? null,
      helper_version: input.helperVersion ?? null,
      platform_metadata: input.platformMetadata,
      last_seen_at: new Date().toISOString(),
    })
    .eq("id", deviceId)
    .eq("user_id", account.user.id)
    .is("revoked_at", null)
    .select("*")
    .maybeSingle();

  if (deviceError) {
    throw new Error(deviceError.message);
  }

  if (!device) {
    return null;
  }

  const { data: health, error: healthError } = await supabase
    .from("quietgate_device_health")
    .insert({
      device_id: deviceId,
      app_version: input.appVersion ?? null,
      helper_version: input.helperVersion ?? null,
      ruleset_version: input.rulesetVersion ?? null,
      script_versions: input.scriptVersions,
      canary_status: input.canaryStatus,
      adult_protection: input.adultProtection,
      platform_metadata: input.platformMetadata,
    })
    .select("id, device_id, reported_at")
    .single();

  if (healthError) {
    throw new Error(healthError.message);
  }

  return {
    device: device as Record<string, unknown>,
    health: health as Record<string, unknown>,
  };
}

export async function recordQuietGateSiteUsageForDeviceContext(
  supabase: QuietGateSupabaseClient,
  userId: string,
  device: Record<string, unknown>,
  input: SiteUsageReportRequest,
) {
  const deviceId = typeof device.id === "string" ? device.id : null;
  if (!deviceId || input.sites.length === 0) {
    return { recorded: 0 };
  }

  const now = new Date().toISOString();
  const source = sourceMetadata(device, input);
  const rows = input.sites.map((usage) => {
    const siteID = usage.siteID;
    const totalSeconds = nonNegativeInt(usage.totalSeconds);
    const limitSeconds = nullableNonNegativeInt(usage.limitSeconds);
    const activityCount = rowActivityCount(siteID, usage);
    const lifetimeActivityCount = rowLifetimeActivityCount(siteID, usage);

    return {
      user_id: userId,
      device_id: deviceId,
      site_id: siteID,
      usage_date: usage.date,
      total_seconds: totalSeconds,
      lifetime_seconds: nonNegativeInt(usage.lifetimeSeconds),
      activity_count: activityCount,
      lifetime_activity_count: lifetimeActivityCount,
      activity_label: usage.activityLabel || defaultActivityLabel(siteID),
      limit_seconds: limitSeconds,
      limit_reached: Boolean(usage.limitReached) || Boolean(limitSeconds && totalSeconds >= limitSeconds),
      source_type: source.sourceType,
      source_id: source.sourceID,
      source_label: source.label,
      browser_id: source.browserID,
      browser_name: source.browserName,
      profile_id: source.profileID,
      profile_name: source.profileName,
      device_name: source.deviceName,
      platform_metadata: source.platformMetadata,
      last_usage_at: usage.lastUpdatedAt || now,
    };
  });

  const { error } = await supabase
    .from("quietgate_site_usage")
    .upsert(rows, {
      onConflict: "user_id,site_id,usage_date,source_id",
    });

  if (error) {
    throw new Error(error.message);
  }

  await supabase
    .from("quietgate_devices")
    .update({ last_seen_at: now })
    .eq("id", deviceId)
    .eq("user_id", userId)
    .is("revoked_at", null);

  return { recorded: rows.length };
}

export async function getQuietGateSiteUsageSummaryForUser(
  supabase: QuietGateSupabaseClient,
  userId: string,
  date = localDateKey(),
) {
  const { data, error } = await supabase
    .from("quietgate_site_usage")
    .select("*")
    .eq("user_id", userId)
    .order("usage_date", { ascending: false })
    .order("updated_at", { ascending: false });

  if (error) {
    throw new Error(error.message);
  }

  return siteUsageSummaryFromRows((data ?? []) as SiteUsageRow[], date);
}

export async function getQuietGateSiteUsageSummary(
  identity?: QuietGateIdentity | null,
) {
  const account = await ensureQuietGateAccount(null, identity);
  const supabase = await createQuietGateDataClient(identity ?? undefined);
  return getQuietGateSiteUsageSummaryForUser(supabase, account.user.id);
}

export async function recordQuietGateSiteUsage(
  deviceId: string,
  input: SiteUsageReportRequest,
  identity?: QuietGateIdentity | null,
) {
  const account = await ensureQuietGateAccount(null, identity);
  const supabase = await createQuietGateDataClient(identity ?? undefined);
  const { data: device, error: deviceError } = await supabase
    .from("quietgate_devices")
    .select("*")
    .eq("id", deviceId)
    .eq("user_id", account.user.id)
    .is("revoked_at", null)
    .maybeSingle();

  if (deviceError) {
    throw new Error(deviceError.message);
  }

  if (!device) {
    return null;
  }

  await recordQuietGateSiteUsageForDeviceContext(
    supabase,
    account.user.id,
    device as Record<string, unknown>,
    input,
  );

  return getQuietGateSiteUsageSummaryForUser(supabase, account.user.id);
}
