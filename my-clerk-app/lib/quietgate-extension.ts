import "server-only";

import crypto from "node:crypto";
import {
  type ExtensionExchangeRequest,
  type ExtensionHealthRequest,
  type ExtensionLinkRequest,
} from "@/lib/extension-contract";
import { createSupabaseAdminClient } from "@/lib/supabase-admin";
import {
  ensureQuietGateAccount,
  getQuietGateSiteUsageSummaryForUser,
  recordQuietGateSiteUsageForDeviceContext,
} from "@/lib/quietgate-supabase";
import { parsePolicy, type PolicyEnvelope } from "@/lib/policy-contract";
import type { SiteUsageReportRequest } from "@/lib/site-usage-contract";

const LINK_CODE_TTL_MS = 5 * 60 * 1000;
const DEVICE_TOKEN_PREFIX = "qgdt_";
const DEV_CHROME_EXTENSION_ID = "fedpnejbgmllajjlfkahlnjbgfmjjmmf";

type DeviceTokenRow = {
  id: string;
  user_id: string;
  device_id: string;
  scopes: string[];
  revoked_at: string | null;
};

type PolicyRow = {
  policy: unknown;
  settings_version: number;
  updated_at: string;
};

export class ExtensionAuthError extends Error {
  status: number;
  code: "forbidden" | "invalid_link_code" | "invalid_device_token" | "not_found";

  constructor(
    status: number,
    code: "forbidden" | "invalid_link_code" | "invalid_device_token" | "not_found",
    message: string,
  ) {
    super(message);
    this.name = "ExtensionAuthError";
    this.status = status;
    this.code = code;
  }
}

function base64URL(bytes = 32) {
  return crypto.randomBytes(bytes).toString("base64url");
}

function sha256(value: string) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function allowedExtensionIDs() {
  const configured = (process.env.QUIETGATE_CHROME_EXTENSION_IDS || "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);

  if (process.env.NODE_ENV !== "production") {
    configured.push(DEV_CHROME_EXTENSION_ID);
  }

  return new Set(configured);
}

export function isAllowedExtensionID(extensionId: string) {
  return allowedExtensionIDs().has(extensionId);
}

function assertAllowedExtensionID(extensionId: string) {
  if (!isAllowedExtensionID(extensionId)) {
    throw new ExtensionAuthError(
      403,
      "forbidden",
      "This Chrome extension ID is not allowed for QuietGate production sync.",
    );
  }
}

function toPolicyEnvelope(row: PolicyRow): PolicyEnvelope {
  return {
    policy: parsePolicy(row.policy),
    settingsVersion: row.settings_version,
    updatedAt: row.updated_at,
  };
}

export async function createExtensionLinkCode(input: ExtensionLinkRequest) {
  assertAllowedExtensionID(input.extensionId);
  const account = await ensureQuietGateAccount();
  const supabase = createSupabaseAdminClient();
  const code = base64URL(24);
  const expiresAt = new Date(Date.now() + LINK_CODE_TTL_MS).toISOString();

  const { error } = await supabase.from("quietgate_extension_link_codes").insert({
    user_id: account.user.id,
    code_hash: sha256(code),
    nonce_hash: sha256(input.nonce),
    extension_id: input.extensionId,
    installation_id: input.installationId,
    extension_version: input.extensionVersion,
    expires_at: expiresAt,
  });

  if (error) {
    throw new Error(error.message);
  }

  return {
    code,
    expiresAt,
    userEmail: account.user.primary_email,
  };
}

export async function exchangeExtensionLinkCode(input: ExtensionExchangeRequest) {
  assertAllowedExtensionID(input.extensionId);
  const supabase = createSupabaseAdminClient();
  const codeHash = sha256(input.code);

  const { data: linkCode, error: linkError } = await supabase
    .from("quietgate_extension_link_codes")
    .select("*")
    .eq("code_hash", codeHash)
    .maybeSingle();

  if (linkError) {
    throw new Error(linkError.message);
  }

  if (
    !linkCode ||
    linkCode.consumed_at ||
    Date.parse(linkCode.expires_at) < Date.now() ||
    linkCode.extension_id !== input.extensionId ||
    linkCode.installation_id !== input.installationId ||
    linkCode.nonce_hash !== sha256(input.nonce)
  ) {
    throw new ExtensionAuthError(
      401,
      "invalid_link_code",
      "This extension link code is invalid or expired.",
    );
  }

  const now = new Date().toISOString();
  const { data: consumedLinkCode, error: consumeError } = await supabase
    .from("quietgate_extension_link_codes")
    .update({ consumed_at: now })
    .eq("id", linkCode.id)
    .is("consumed_at", null)
    .select("*")
    .maybeSingle();

  if (consumeError) {
    throw new Error(consumeError.message);
  }

  if (!consumedLinkCode) {
    throw new ExtensionAuthError(
      401,
      "invalid_link_code",
      "This extension link code is invalid or expired.",
    );
  }

  const { data: device, error: deviceError } = await supabase
    .from("quietgate_devices")
    .upsert(
      {
        user_id: consumedLinkCode.user_id,
        installation_id: input.installationId,
        platform: "chrome_extension",
        name: "QuietGate for Chrome",
        app_version: input.extensionVersion,
        helper_version: null,
        platform_metadata: {
          extensionId: input.extensionId,
          auth: "chrome_store",
        },
        last_seen_at: now,
        revoked_at: null,
      },
      { onConflict: "user_id,installation_id" },
    )
    .select("*")
    .single();

  if (deviceError) {
    throw new Error(deviceError.message);
  }

  await supabase
    .from("quietgate_device_tokens")
    .update({ revoked_at: now })
    .eq("device_id", device.id)
    .is("revoked_at", null);

  const deviceToken = `${DEVICE_TOKEN_PREFIX}${base64URL(36)}`;
  const { error: tokenError } = await supabase
    .from("quietgate_device_tokens")
    .insert({
      user_id: consumedLinkCode.user_id,
      device_id: device.id,
      token_hash: sha256(deviceToken),
      token_prefix: deviceToken.slice(0, 12),
    });

  if (tokenError) {
    throw new Error(tokenError.message);
  }

  return {
    device,
    deviceToken,
  };
}

function tokenFromAuthorizationHeader(authorization: string | null) {
  const match = authorization?.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

export async function authenticateExtensionDevice(authorization: string | null) {
  const token = tokenFromAuthorizationHeader(authorization);
  if (!token?.startsWith(DEVICE_TOKEN_PREFIX)) {
    throw new ExtensionAuthError(
      401,
      "invalid_device_token",
      "Missing or invalid QuietGate device token.",
    );
  }

  const supabase = createSupabaseAdminClient();
  const tokenHash = sha256(token);
  const { data: tokenRow, error: tokenError } = await supabase
    .from("quietgate_device_tokens")
    .select("id, user_id, device_id, scopes, revoked_at")
    .eq("token_hash", tokenHash)
    .is("revoked_at", null)
    .maybeSingle();

  if (tokenError) {
    throw new Error(tokenError.message);
  }

  if (!tokenRow) {
    throw new ExtensionAuthError(
      401,
      "invalid_device_token",
      "QuietGate device token is revoked or unknown.",
    );
  }

  const typedToken = tokenRow as DeviceTokenRow;
  const { data: device, error: deviceError } = await supabase
    .from("quietgate_devices")
    .select("*")
    .eq("id", typedToken.device_id)
    .is("revoked_at", null)
    .maybeSingle();

  if (deviceError) {
    throw new Error(deviceError.message);
  }

  if (!device) {
    throw new ExtensionAuthError(404, "not_found", "QuietGate device is revoked or missing.");
  }

  await supabase
    .from("quietgate_device_tokens")
    .update({ last_used_at: new Date().toISOString() })
    .eq("id", typedToken.id);

  return {
    supabase,
    token: typedToken,
    device: device as Record<string, unknown>,
  };
}

export async function getExtensionPolicy(authorization: string | null) {
  const context = await authenticateExtensionDevice(authorization);
  const { data, error } = await context.supabase
    .from("quietgate_policies")
    .select("policy, settings_version, updated_at")
    .eq("user_id", context.token.user_id)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return {
    device: context.device,
    policy: toPolicyEnvelope(data as PolicyRow),
  };
}

export async function recordExtensionHealth(
  authorization: string | null,
  input: ExtensionHealthRequest,
) {
  const context = await authenticateExtensionDevice(authorization);
  const now = new Date().toISOString();
  const { data: device, error: deviceError } = await context.supabase
    .from("quietgate_devices")
    .update({
      app_version: input.extensionVersion,
      platform_metadata: input.platformMetadata,
      last_seen_at: now,
    })
    .eq("id", context.token.device_id)
    .is("revoked_at", null)
    .select("*")
    .single();

  if (deviceError) {
    throw new Error(deviceError.message);
  }

  const { data: health, error: healthError } = await context.supabase
    .from("quietgate_device_health")
    .insert({
      device_id: context.token.device_id,
      app_version: input.extensionVersion,
      helper_version: null,
      ruleset_version: input.rulesetVersion,
      script_versions: input.scriptVersions,
      canary_status: input.canaryStatus,
      adult_protection: input.adultProtection,
      platform_metadata: input.platformMetadata,
      enabled_permissions: input.enabledPermissions,
      recent_block_counters: input.recentBlockCounters,
      last_sync_at: input.lastSyncAt,
    })
    .select("id, device_id, reported_at")
    .single();

  if (healthError) {
    throw new Error(healthError.message);
  }

  return {
    device,
    health,
  };
}

export async function getExtensionSiteUsage(authorization: string | null) {
  const context = await authenticateExtensionDevice(authorization);
  return {
    device: context.device,
    siteUsageSummary: await getQuietGateSiteUsageSummaryForUser(
      context.supabase,
      context.token.user_id,
    ),
  };
}

export async function recordExtensionSiteUsage(
  authorization: string | null,
  input: SiteUsageReportRequest,
) {
  const context = await authenticateExtensionDevice(authorization);
  await recordQuietGateSiteUsageForDeviceContext(
    context.supabase,
    context.token.user_id,
    context.device,
    input,
  );

  return {
    device: context.device,
    siteUsageSummary: await getQuietGateSiteUsageSummaryForUser(
      context.supabase,
      context.token.user_id,
    ),
  };
}

export async function revokeExtensionDevice(authorization: string | null) {
  const context = await authenticateExtensionDevice(authorization);
  const now = new Date().toISOString();
  await context.supabase
    .from("quietgate_device_tokens")
    .update({ revoked_at: now })
    .eq("device_id", context.token.device_id)
    .is("revoked_at", null);

  const { data: device, error } = await context.supabase
    .from("quietgate_devices")
    .update({ revoked_at: now })
    .eq("id", context.token.device_id)
    .select("*")
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return { device };
}
