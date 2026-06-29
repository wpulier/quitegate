import { SignInButton, SignUpButton } from "@clerk/nextjs";
import { auth, currentUser } from "@clerk/nextjs/server";
import {
  ensureQuietGateAccount,
  hasQuietGateDataConfig,
  listQuietGateDevices,
} from "@/lib/quietgate-supabase";

type DeviceRow = {
  id?: string;
  platform?: string;
  name?: string | null;
  app_version?: string | null;
  helper_version?: string | null;
  last_seen_at?: string | null;
  platform_metadata?: unknown;
};

type DeviceStatus = "Not installed" | "Signed in" | "Setup incomplete" | "Protected" | "Stale";

const deviceGroups = [
  {
    title: "Mac app",
    platforms: ["macos"],
    empty: "Install and sign in from the Mac app to sync policy and protection health.",
    action: "Mac setup pending",
  },
  {
    title: "iPhone and iPad",
    platforms: ["ios"],
    empty: "Install the TestFlight build, sign in, and register this account.",
    action: "TestFlight pending",
  },
  {
    title: "Chrome extension",
    platforms: ["chrome_extension", "chrome"],
    empty: "Connect the browser extension to apply web policy from this account.",
    action: "Connect extension",
    href: "/extension/connect",
  },
];

function statusTone(status: DeviceStatus) {
  switch (status) {
    case "Protected":
      return "bg-emerald-50 text-emerald-700 ring-emerald-200";
    case "Signed in":
      return "bg-blue-50 text-blue-700 ring-blue-200";
    case "Setup incomplete":
      return "bg-amber-50 text-amber-700 ring-amber-200";
    case "Stale":
      return "bg-zinc-100 text-zinc-700 ring-zinc-200";
    default:
      return "bg-zinc-100 text-zinc-600 ring-zinc-200";
  }
}

function isStale(lastSeenAt?: string | null) {
  if (!lastSeenAt) {
    return false;
  }

  const lastSeen = Date.parse(lastSeenAt);
  return Number.isFinite(lastSeen) && Date.now() - lastSeen > 24 * 60 * 60 * 1000;
}

function metadataRecord(device: DeviceRow) {
  const metadata = device.platform_metadata;
  return metadata && typeof metadata === "object"
    ? (metadata as Record<string, unknown>)
    : {};
}

function deviceStatus(device?: DeviceRow): DeviceStatus {
  if (!device) {
    return "Not installed";
  }

  if (isStale(device.last_seen_at)) {
    return "Stale";
  }

  const metadata = metadataRecord(device);
  if (metadata.protected === true || metadata.setupStatus === "protected") {
    return "Protected";
  }

  if (metadata.setupStatus === "incomplete") {
    return "Setup incomplete";
  }

  return "Signed in";
}

function formatDate(value?: string | null) {
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

function newestDevice(devices: DeviceRow[], platforms: string[]) {
  return devices.find((device) => platforms.includes(device.platform ?? ""));
}

function DeviceCard({
  action,
  device,
  empty,
  href,
  title,
}: {
  action: string;
  device?: DeviceRow;
  empty: string;
  href?: string;
  title: string;
}) {
  const status = deviceStatus(device);

  return (
    <article className="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h3 className="text-base font-semibold text-zinc-950">{title}</h3>
          <p className="mt-2 text-sm leading-6 text-zinc-600">
            {device?.name || empty}
          </p>
        </div>
        <span
          className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-medium ring-1 ${statusTone(status)}`}
        >
          {status}
        </span>
      </div>
      <dl className="mt-5 grid gap-3 text-sm text-zinc-600 sm:grid-cols-2">
        <div>
          <dt className="font-medium text-zinc-500">Last seen</dt>
          <dd className="mt-1 text-zinc-900">{formatDate(device?.last_seen_at)}</dd>
        </div>
        <div>
          <dt className="font-medium text-zinc-500">Version</dt>
          <dd className="mt-1 text-zinc-900">
            {device?.app_version || device?.helper_version || "Not reported"}
          </dd>
        </div>
      </dl>
      {href ? (
        <a
          className="mt-5 inline-flex rounded-md bg-zinc-950 px-3 py-2 text-sm font-medium text-white transition hover:bg-zinc-800"
          href={href}
        >
          {action}
        </a>
      ) : (
        <p className="mt-5 text-sm font-medium text-zinc-500">{action}</p>
      )}
    </article>
  );
}

export default async function Home() {
  const { userId } = await auth();
  const user = userId ? await currentUser() : null;
  const email = user?.primaryEmailAddress?.emailAddress ?? null;
  const dataConfigured = hasQuietGateDataConfig();
  let quietGateUserId: string | null = null;
  let devices: DeviceRow[] = [];
  let policyMode: string | null = null;
  let adultBlocking = false;
  let settingsVersion: number | null = null;
  let updatedAt: string | null = null;
  let syncUnavailable = false;

  if (userId && dataConfigured) {
    try {
      const account = await ensureQuietGateAccount(email);
      quietGateUserId = account.user.id;
      policyMode = account.policy.policy.mode;
      adultBlocking = account.policy.policy.adultBlockingEnabled;
      settingsVersion = account.policy.settingsVersion;
      updatedAt = account.policy.updatedAt;
      devices = (await listQuietGateDevices()) as DeviceRow[];
    } catch {
      syncUnavailable = true;
    }
  }

  const signedIn = Boolean(userId);

  return (
    <main className="min-h-[calc(100vh-4rem)] bg-zinc-50">
      <section className="mx-auto flex w-full max-w-6xl flex-col gap-8 px-6 py-12">
        <div className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
          <div className="max-w-2xl">
            <p className="mb-3 text-sm font-medium uppercase tracking-[0.18em] text-zinc-500">
              Account hub
            </p>
            <h1 className="text-4xl font-semibold tracking-tight text-zinc-950 sm:text-5xl">
              Tortoise connects your Mac, iPhone, and browser protection.
            </h1>
            <p className="mt-5 text-lg leading-8 text-zinc-600">
              Use this dashboard for account status, setup progress, device
              health, and recovery. Protection itself runs in the native apps
              and browser extension.
            </p>
          </div>

          {!signedIn ? (
            <div className="flex shrink-0 gap-3">
              <SignInButton>
                <button className="rounded-md border border-zinc-300 bg-white px-4 py-2 text-sm font-medium text-zinc-900 shadow-sm transition hover:bg-zinc-100">
                  Sign in
                </button>
              </SignInButton>
              <SignUpButton>
                <button className="rounded-md bg-zinc-950 px-4 py-2 text-sm font-medium text-white shadow-sm transition hover:bg-zinc-800">
                  Create account
                </button>
              </SignUpButton>
            </div>
          ) : null}
        </div>

        <div className="grid gap-4 lg:grid-cols-3">
          <section className="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm">
            <p className="text-sm font-medium text-zinc-500">Account</p>
            <h2 className="mt-2 text-2xl font-semibold text-zinc-950">
              {signedIn ? "Signed in" : "Signed out"}
            </h2>
            <p className="mt-3 text-sm leading-6 text-zinc-600">
              {email || quietGateUserId || "Sign in to sync policy across devices."}
            </p>
          </section>

          <section className="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm">
            <p className="text-sm font-medium text-zinc-500">Plan</p>
            <h2 className="mt-2 text-2xl font-semibold text-zinc-950">
              {signedIn ? "Beta access" : "Account required"}
            </h2>
            <p className="mt-3 text-sm leading-6 text-zinc-600">
              Billing is account-level. TestFlight builds use beta access until
              paid plans are turned on.
            </p>
          </section>

          <section className="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm">
            <p className="text-sm font-medium text-zinc-500">Policy sync</p>
            <h2 className="mt-2 text-2xl font-semibold text-zinc-950">
              {!signedIn
                ? "Waiting for sign in"
                : !dataConfigured || syncUnavailable
                  ? "Policy sync unavailable"
                  : "Current"}
            </h2>
            <p className="mt-3 text-sm leading-6 text-zinc-600">
              {!signedIn
                ? "Sign in to create your shared policy."
                : !dataConfigured
                  ? "Reconnect Supabase server configuration."
                  : syncUnavailable
                    ? "Try again after the account database is reachable."
                    : `${policyMode ?? "open"} mode, version ${settingsVersion ?? 0}.`}
            </p>
          </section>
        </div>

        <section>
          <div className="mb-4 flex items-center justify-between gap-4">
            <div>
              <h2 className="text-2xl font-semibold tracking-tight text-zinc-950">
                Devices
              </h2>
              <p className="mt-1 text-sm text-zinc-600">
                Setup status for each interaction surface.
              </p>
            </div>
          </div>
          <div className="grid gap-4 lg:grid-cols-3">
            {deviceGroups.map((group) => (
              <DeviceCard
                key={group.title}
                action={group.action}
                device={newestDevice(devices, group.platforms)}
                empty={group.empty}
                href={group.href}
                title={group.title}
              />
            ))}
          </div>
        </section>

        <section className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
          <div className="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
            <div>
              <p className="text-sm font-medium text-zinc-500">Policy</p>
              <h2 className="mt-2 text-2xl font-semibold text-zinc-950">
                {policyMode ? `${policyMode} mode` : "No policy loaded"}
              </h2>
              <p className="mt-3 max-w-2xl text-sm leading-6 text-zinc-600">
                Adult blocking is {adultBlocking ? "on" : "off"}. Local app
                settings are cached copies; Supabase remains the canonical
                policy source.
              </p>
            </div>
            <dl className="grid min-w-64 gap-4 text-sm sm:grid-cols-2 lg:grid-cols-1">
              <div>
                <dt className="font-medium text-zinc-500">Version</dt>
                <dd className="mt-1 text-zinc-950">{settingsVersion ?? "Unavailable"}</dd>
              </div>
              <div>
                <dt className="font-medium text-zinc-500">Last updated</dt>
                <dd className="mt-1 text-zinc-950">{formatDate(updatedAt)}</dd>
              </div>
            </dl>
          </div>
        </section>
      </section>
    </main>
  );
}
