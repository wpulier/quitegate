import type { PolicyEnvelope, QuietGatePolicy } from "@/lib/policy-contract";

export type DeviceHealthRow = {
  id?: string;
  device_id?: string;
  reported_at?: string | null;
  app_version?: string | null;
  helper_version?: string | null;
  ruleset_version?: string | null;
  script_versions?: unknown;
  canary_status?: unknown;
  adult_protection?: unknown;
  platform_metadata?: unknown;
};

export type DashboardDevice = {
  id?: string;
  platform?: string;
  name?: string | null;
  app_version?: string | null;
  helper_version?: string | null;
  last_seen_at?: string | null;
  platform_metadata?: unknown;
  latest_health?: DeviceHealthRow | null;
};

export type DeviceStatus =
  | "Not installed"
  | "Signed in"
  | "Setup incomplete"
  | "Synced"
  | "Protected"
  | "Partially protected"
  | "Unsupported on this device"
  | "Stale";

type Surface = "macos" | "ios" | "chrome";
type Capability = "supported" | "not_supported" | "not_supported_v1" | "planned";

export type CoverageRow = {
  id: string;
  label: string;
  policyState: string;
  mac: string;
  ios: string;
  chrome: string;
};

const DAY_MS = 24 * 60 * 60 * 1000;

const featureGroups = [
  {
    id: "adult-web",
    label: "Adult web blocking",
    isOn: (policy: QuietGatePolicy) =>
      policy.adultBlockingEnabled ||
      policy.browser.blockedCategories.includes("adultContent"),
    capabilities: {
      macos: "supported",
      ios: "planned",
      chrome: "supported",
    },
  },
  {
    id: "x",
    label: "X tuning",
    isOn: (policy: QuietGatePolicy) =>
      Object.entries(policy.browser.features).some(
        ([feature, enabled]) => enabled && feature.startsWith("x"),
      ),
    capabilities: {
      macos: "supported",
      ios: "not_supported_v1",
      chrome: "supported",
    },
  },
  {
    id: "reddit",
    label: "Reddit tuning",
    isOn: (policy: QuietGatePolicy) =>
      Object.entries(policy.browser.features).some(
        ([feature, enabled]) => enabled && feature.startsWith("reddit"),
      ),
    capabilities: {
      macos: "supported",
      ios: "not_supported_v1",
      chrome: "supported",
    },
  },
  {
    id: "youtube",
    label: "YouTube tuning",
    isOn: (policy: QuietGatePolicy) =>
      Object.entries(policy.browser.features).some(
        ([feature, enabled]) => enabled && feature.startsWith("youtube"),
      ),
    capabilities: {
      macos: "supported",
      ios: "not_supported_v1",
      chrome: "supported",
    },
  },
  {
    id: "instagram",
    label: "Instagram blocking",
    isOn: (policy: QuietGatePolicy) =>
      Object.entries(policy.browser.features).some(
        ([feature, enabled]) => enabled && feature.startsWith("instagram"),
      ),
    capabilities: {
      macos: "supported",
      ios: "not_supported_v1",
      chrome: "supported",
    },
  },
  {
    id: "mac-apps",
    label: "Mac app blocking",
    isOn: (policy: QuietGatePolicy) =>
      policy.applications.enforcementEnabled &&
      policy.applications.blocked.some((rule) => rule.isEnabled),
    capabilities: {
      macos: "supported",
      ios: "not_supported",
      chrome: "not_supported",
    },
  },
  {
    id: "schedules",
    label: "Focus schedules",
    isOn: (policy: QuietGatePolicy) =>
      policy.schedules.enabled &&
      policy.schedules.dailyFocusWindows.some((window) => window.isEnabled),
    capabilities: {
      macos: "supported",
      ios: "planned",
      chrome: "planned",
    },
  },
] satisfies Array<{
  id: string;
  label: string;
  isOn: (policy: QuietGatePolicy) => boolean;
  capabilities: Record<Surface, Capability>;
}>;

export function statusTone(status: DeviceStatus) {
  switch (status) {
    case "Protected":
      return "bg-emerald-50 text-emerald-700 ring-emerald-200";
    case "Synced":
      return "bg-blue-50 text-blue-700 ring-blue-200";
    case "Signed in":
      return "bg-sky-50 text-sky-700 ring-sky-200";
    case "Partially protected":
    case "Setup incomplete":
      return "bg-amber-50 text-amber-700 ring-amber-200";
    case "Unsupported on this device":
      return "bg-violet-50 text-violet-700 ring-violet-200";
    case "Stale":
      return "bg-zinc-100 text-zinc-700 ring-zinc-200";
    default:
      return "bg-zinc-100 text-zinc-600 ring-zinc-200";
  }
}

export function isStale(value?: string | null) {
  if (!value) {
    return false;
  }

  const timestamp = Date.parse(value);
  return Number.isFinite(timestamp) && Date.now() - timestamp > DAY_MS;
}

export function formatDate(value?: string | null) {
  if (!value) {
    return "Never";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "Unknown";
  }

  return date.toLocaleString("en", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

export function newestDevice(devices: DashboardDevice[], platforms: string[]) {
  return devices.find((device) => platforms.includes(device.platform ?? ""));
}

export function presentDeviceStatus(
  device: DashboardDevice | undefined,
  policy: PolicyEnvelope | null,
): DeviceStatus {
  if (!device) {
    return "Not installed";
  }

  if (isStale(device.last_seen_at)) {
    return "Stale";
  }

  const metadata = mergedMetadata(device);
  const setupStatus = stringValue(metadata.setupStatus);
  const reportedPolicyVersion = stringValue(metadata.policyVersion);
  const policyVersion = policy ? String(policy.settingsVersion) : null;
  const latestHealth = device.latest_health;
  const hasCurrentPolicy =
    Boolean(policyVersion) && reportedPolicyVersion === policyVersion;

  if (setupStatus === "setup_incomplete" || setupStatus === "incomplete") {
    return "Setup incomplete";
  }

  if (device.platform === "ios") {
    return hasCurrentPolicy ? "Synced" : "Signed in";
  }

  if (hasCurrentPolicy && setupStatus === "protected" && hasPassingProof(latestHealth)) {
    return "Protected";
  }

  if (hasCurrentPolicy && hasPartialProof(latestHealth)) {
    return "Partially protected";
  }

  if (hasCurrentPolicy || latestHealth) {
    return "Synced";
  }

  return "Signed in";
}

export function deviceDetail(device?: DashboardDevice) {
  if (!device) {
    return "No device has registered for this surface yet.";
  }

  const metadata = mergedMetadata(device);
  const policyVersion = stringValue(metadata.policyVersion);
  if (device.platform === "ios") {
    return policyVersion
      ? `Account hub synced policy version ${policyVersion}. iOS enforcement is not available in v1.`
      : "Signed in as an account hub. iOS enforcement is not available in v1.";
  }

  if (policyVersion) {
    return `Reported policy version ${policyVersion}.`;
  }

  return "Signed in, but this device has not reported policy health yet.";
}

export function buildCoverageRows(
  policy: PolicyEnvelope | null,
  devices: DashboardDevice[],
): CoverageRow[] {
  const macDevice = newestDevice(devices, ["macos"]);
  const iosDevice = newestDevice(devices, ["ios"]);
  const chromeDevice = newestDevice(devices, ["chrome_extension", "chrome"]);

  return featureGroups.map((group) => {
    const policyIsOn = policy ? group.isOn(policy.policy) : false;

    return {
      id: group.id,
      label: group.label,
      policyState: policy ? (policyIsOn ? "Policy On" : "Policy Off") : "Unknown",
      mac: coverageStatus(policyIsOn, group.capabilities.macos, macDevice, policy),
      ios: coverageStatus(policyIsOn, group.capabilities.ios, iosDevice, policy),
      chrome: coverageStatus(policyIsOn, group.capabilities.chrome, chromeDevice, policy),
    };
  });
}

function coverageStatus(
  policyIsOn: boolean,
  capability: Capability,
  device: DashboardDevice | undefined,
  policy: PolicyEnvelope | null,
) {
  if (!policyIsOn) {
    return "Off by policy";
  }

  switch (capability) {
    case "not_supported_v1":
      return "Not available on iOS yet";
    case "not_supported":
      return "Not supported here";
    case "planned":
      return "Planned";
    default:
      break;
  }

  const status = presentDeviceStatus(device, policy);
  if (status === "Protected") {
    return "Live";
  }
  if (status === "Synced") {
    return "Synced, no enforcement proof";
  }
  return status;
}

function mergedMetadata(device: DashboardDevice) {
  return {
    ...recordValue(device.platform_metadata),
    ...recordValue(device.latest_health?.platform_metadata),
  };
}

function recordValue(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value : null;
}

function hasPassingProof(health?: DeviceHealthRow | null) {
  const canaryStatus = recordValue(health?.canary_status);
  const adultProtection = recordValue(health?.adult_protection);
  const values = [...Object.values(canaryStatus), ...Object.values(adultProtection)];

  return values.some((value) => {
    if (typeof value !== "string") {
      return false;
    }

    return ["ok", "live", "passed", "protected"].includes(value.toLowerCase());
  });
}

function hasPartialProof(health?: DeviceHealthRow | null) {
  return Boolean(
    health &&
      (Object.keys(recordValue(health.canary_status)).length > 0 ||
        Object.keys(recordValue(health.adult_protection)).length > 0),
  );
}
