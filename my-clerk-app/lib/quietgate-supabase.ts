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
