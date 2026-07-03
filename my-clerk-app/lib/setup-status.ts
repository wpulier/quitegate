import type { PolicyEnvelope, QuietGatePolicy } from "@/lib/policy-contract";
import {
  isStale,
  newestDevice,
  type DashboardDevice,
} from "@/lib/protection-status";

export type SetupStep =
  | "account"
  | "macApp"
  | "iosApp"
  | "screenTime"
  | "safariExtension"
  | "firstTuning"
  | "sync";

export type SetupStepStatus = "complete" | "needsAction" | "blocked" | "checking";

export type ConnectionState =
  | "connected"
  | "partial"
  | "setupRequired"
  | "repairRequired"
  | "stale";

export type SetupStepView = {
  id: SetupStep;
  title: string;
  detail: string;
  status: SetupStepStatus;
  actionLabel: string;
  href: string;
};

export type SetupSummary = {
  state: ConnectionState;
  title: string;
  detail: string;
  steps: SetupStepView[];
  completedCount: number;
  totalCount: number;
};

type SetupInput = {
  signedIn: boolean;
  dataConfigured: boolean;
  syncUnavailable: boolean;
  devices: DashboardDevice[];
  policy: PolicyEnvelope | null;
};

export function deriveSetupSummary(input: SetupInput): SetupSummary {
  const macDevice = newestDevice(input.devices, ["macos"]);
  const iosDevice = newestDevice(input.devices, ["ios"]);
  const iosMetadata = mergedMetadata(iosDevice);
  const iosEnforcement = recordValue(iosMetadata.iosEnforcement);
  const selectedTargetCount =
    numberValue(iosEnforcement.selectedApplicationCount) +
    numberValue(iosEnforcement.selectedCategoryCount) +
    numberValue(iosEnforcement.selectedWebDomainCount);
  const safariState = stringValue(iosEnforcement.safariExtensionState);
  const safariSeenAt = stringValue(iosEnforcement.lastSafariExtensionSeenAt);
  const syncBlocked = !input.dataConfigured || input.syncUnavailable;
  const firstTuningIsOn = input.policy ? policyHasProtection(input.policy.policy) : false;

  const steps: SetupStepView[] = [
    {
      id: "account",
      title: "Create your Tortoise account",
      detail: input.signedIn
        ? "Signed in. Your policy can sync across devices."
        : "Start here so Mac and iPhone use the same settings.",
      status: input.signedIn ? "complete" : "needsAction",
      actionLabel: input.signedIn ? "Account ready" : "Create account",
      href: "/sign-up",
    },
    {
      id: "macApp",
      title: "Install and sign in on Mac",
      detail: macDevice
        ? `${macDevice.name || "Mac"} checked in ${formatRelative(macDevice.last_seen_at)}.`
        : "Download the Mac app, drag it to Applications, then sign in.",
      status: deviceStepStatus(input.signedIn, macDevice),
      actionLabel: macDevice ? "Mac connected" : "Download Mac",
      href: "/download/mac",
    },
    {
      id: "iosApp",
      title: "Install and sign in on iPhone",
      detail: iosDevice
        ? `${iosDevice.name || "iPhone"} checked in ${formatRelative(iosDevice.last_seen_at)}.`
        : "Install the TestFlight build, open Tortoise, and sign in.",
      status: deviceStepStatus(input.signedIn, iosDevice),
      actionLabel: iosDevice ? "iPhone connected" : "Install iPhone",
      href: "/download/ios",
    },
    {
      id: "screenTime",
      title: "Turn on Screen Time protection",
      detail:
        selectedTargetCount > 0
          ? `${selectedTargetCount} iOS target${selectedTargetCount === 1 ? "" : "s"} selected.`
          : "Open the iPhone app, allow Screen Time, and select YouTube/app targets.",
      status: !iosDevice ? "blocked" : selectedTargetCount > 0 ? "complete" : "needsAction",
      actionLabel: selectedTargetCount > 0 ? "Screen Time ready" : "Open iPhone setup",
      href: "/download/ios",
    },
    {
      id: "safariExtension",
      title: "Enable the Safari extension",
      detail: safariExtensionDetail(safariState, safariSeenAt),
      status: !iosDevice
        ? "blocked"
        : safariState === "connected"
          ? "complete"
          : "needsAction",
      actionLabel: safariState === "connected" ? "Safari connected" : "Enable Safari",
      href: "/download/ios",
    },
    {
      id: "firstTuning",
      title: "Turn on the first tuning rule",
      detail: firstTuningIsOn
        ? `Policy is in ${input.policy?.policy.mode ?? "focus"} mode with active protection.`
        : "Open Mac or iPhone and turn on Focus or Strict for YouTube.",
      status: !input.signedIn ? "blocked" : firstTuningIsOn ? "complete" : "needsAction",
      actionLabel: firstTuningIsOn ? "Tuning active" : "Open setup",
      href: "/setup",
    },
    {
      id: "sync",
      title: "Confirm sync health",
      detail: syncBlocked
        ? "Account sync is not reachable. Fix server configuration or retry."
        : "Account, devices, policy, and usage can sync.",
      status: !input.signedIn ? "blocked" : syncBlocked ? "blocked" : "complete",
      actionLabel: syncBlocked ? "Retry later" : "Sync ready",
      href: "/setup",
    },
  ];

  const completedCount = steps.filter((step) => step.status === "complete").length;
  const stale = [macDevice, iosDevice].some((device) => device && isStale(device.last_seen_at));
  const state = connectionState(steps, input.signedIn, syncBlocked, stale);

  return {
    state,
    title: connectionTitle(state),
    detail: connectionDetail(state),
    steps,
    completedCount,
    totalCount: steps.length,
  };
}

export function setupTone(status: SetupStepStatus | ConnectionState) {
  switch (status) {
    case "complete":
    case "connected":
      return "bg-blue-50 text-blue-700 ring-blue-200";
    case "partial":
    case "needsAction":
    case "setupRequired":
      return "bg-amber-50 text-amber-700 ring-amber-200";
    case "repairRequired":
    case "blocked":
      return "bg-red-50 text-red-700 ring-red-200";
    case "stale":
      return "bg-zinc-100 text-zinc-700 ring-zinc-200";
    default:
      return "bg-blue-50 text-blue-700 ring-blue-200";
  }
}

function connectionState(
  steps: SetupStepView[],
  signedIn: boolean,
  syncBlocked: boolean,
  stale: boolean,
): ConnectionState {
  if (!signedIn) {
    return "setupRequired";
  }
  if (syncBlocked || steps.some((step) => step.status === "blocked" && step.id !== "screenTime" && step.id !== "safariExtension")) {
    return "repairRequired";
  }
  if (stale) {
    return "stale";
  }
  if (steps.every((step) => step.status === "complete")) {
    return "connected";
  }
  if (steps.some((step) => step.status === "complete")) {
    return "partial";
  }
  return "setupRequired";
}

function connectionTitle(state: ConnectionState) {
  switch (state) {
    case "connected":
      return "Connected";
    case "partial":
      return "Partially connected";
    case "repairRequired":
      return "Needs repair";
    case "stale":
      return "Stale";
    default:
      return "Setup needed";
  }
}

function connectionDetail(state: ConnectionState) {
  switch (state) {
    case "connected":
      return "Tortoise has the account, devices, setup, policy, and sync proof it needs.";
    case "partial":
      return "Some pieces are working. Finish the remaining checklist items before relying on protection.";
    case "repairRequired":
      return "A required service or connection is unavailable. Fix the blocked item first.";
    case "stale":
      return "A device was connected before, but it has not checked in recently.";
    default:
      return "Start with an account, then install Tortoise on Mac and iPhone.";
  }
}

function deviceStepStatus(signedIn: boolean, device?: DashboardDevice): SetupStepStatus {
  if (!signedIn) {
    return "blocked";
  }
  if (!device) {
    return "needsAction";
  }
  return isStale(device.last_seen_at) ? "needsAction" : "complete";
}

function safariExtensionDetail(state: string | null, seenAt: string | null) {
  if (state === "connected") {
    return `Safari extension heartbeat received${seenAt ? ` ${formatRelative(seenAt)}` : ""}.`;
  }
  if (state === "enabledWaitingForHeartbeat") {
    return "Safari says the extension is enabled. Open YouTube in Safari once to verify it.";
  }
  if (state === "disabled") {
    return "Turn on Tortoise Safari in Settings, then open YouTube once.";
  }
  if (state === "unavailable") {
    return "This iOS version needs the manual Safari extension setup steps.";
  }
  return "Enable Tortoise Safari from the iPhone app checklist.";
}

function policyHasProtection(policy: QuietGatePolicy) {
  return (
    policy.mode !== "open" ||
    policy.adultBlockingEnabled ||
    policy.browser.blockedDomains.length > 0 ||
    policy.browser.blockedCategories.length > 0 ||
    Object.values(policy.browser.features).some(Boolean) ||
    policy.applications.blocked.some((rule) => rule.isEnabled)
  );
}

function mergedMetadata(device?: DashboardDevice) {
  if (!device) {
    return {};
  }

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
  return typeof value === "string" && value.trim() ? value : null;
}

function numberValue(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function formatRelative(value?: string | null) {
  if (!value) {
    return "recently";
  }

  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp)) {
    return "recently";
  }

  const minutes = Math.max(Math.round((Date.now() - timestamp) / 60000), 0);
  if (minutes < 2) {
    return "just now";
  }
  if (minutes < 60) {
    return `${minutes} minutes ago`;
  }

  const hours = Math.round(minutes / 60);
  if (hours < 24) {
    return `${hours} hours ago`;
  }

  const days = Math.round(hours / 24);
  return `${days} days ago`;
}
