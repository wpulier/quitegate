import { SignInButton, SignUpButton } from "@clerk/nextjs";
import { auth, currentUser } from "@clerk/nextjs/server";
import {
  ensureQuietGateAccount,
  hasQuietGateDataConfig,
  listQuietGateDevices,
} from "@/lib/quietgate-supabase";
import {
  buildCoverageRows,
  deviceDetail,
  formatDate,
  newestDevice,
  presentDeviceStatus,
  statusTone,
  type DashboardDevice,
  type DeviceStatus,
} from "@/lib/protection-status";
import type { PolicyEnvelope } from "@/lib/policy-contract";

const deviceGroups = [
  {
    title: "Mac app",
    platforms: ["macos"],
    empty: "Install and sign in from the Mac app to edit policy and enforce desktop/browser protection.",
    action: "Download Mac",
  },
  {
    title: "iPhone and iPad",
    platforms: ["ios"],
    empty: "Install the TestFlight build and sign in to sync account, policy, and setup status.",
    action: "Open TestFlight",
    href: "https://testflight.apple.com/",
  },
  {
    title: "Chrome extension",
    platforms: ["chrome_extension", "chrome"],
    empty: "Connect the browser extension to apply web policy from this account.",
    action: "Connect Chrome",
    href: "/extension/connect",
  },
];

function StatusPill({ status }: { status: DeviceStatus | string }) {
  return (
    <span
      className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-medium ring-1 ${statusTone(
        status as DeviceStatus,
      )}`}
    >
      {status}
    </span>
  );
}

function DeviceCard({
  action,
  device,
  empty,
  href,
  policy,
  title,
}: {
  action: string;
  device?: DashboardDevice;
  empty: string;
  href?: string;
  policy: PolicyEnvelope | null;
  title: string;
}) {
  const status = presentDeviceStatus(device, policy);

  return (
    <article className="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h3 className="text-base font-semibold text-zinc-950">{title}</h3>
          <p className="mt-2 text-sm leading-6 text-zinc-600">
            {device?.name || empty}
          </p>
          {device ? (
            <p className="mt-2 text-xs leading-5 text-zinc-500">
              {deviceDetail(device)}
            </p>
          ) : null}
        </div>
        <StatusPill status={status} />
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

function SetupLink({
  description,
  href,
  label,
  title,
}: {
  description: string;
  href?: string;
  label: string;
  title: string;
}) {
  const content = (
    <div className="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm transition hover:border-zinc-300">
      <h3 className="text-base font-semibold text-zinc-950">{title}</h3>
      <p className="mt-2 min-h-12 text-sm leading-6 text-zinc-600">{description}</p>
      <p className="mt-4 text-sm font-medium text-zinc-950">{label}</p>
    </div>
  );

  return href ? <a href={href}>{content}</a> : content;
}

export default async function Home() {
  const { userId } = await auth();
  const user = userId ? await currentUser() : null;
  const email = user?.primaryEmailAddress?.emailAddress ?? null;
  const dataConfigured = hasQuietGateDataConfig();
  let quietGateUserId: string | null = null;
  let devices: DashboardDevice[] = [];
  let policyEnvelope: PolicyEnvelope | null = null;
  let syncUnavailable = false;

  if (userId && dataConfigured) {
    try {
      const account = await ensureQuietGateAccount(email);
      quietGateUserId = account.user.id;
      policyEnvelope = account.policy;
      devices = (await listQuietGateDevices()) as DashboardDevice[];
    } catch {
      syncUnavailable = true;
    }
  }

  const signedIn = Boolean(userId);
  const policyMode = policyEnvelope?.policy.mode ?? null;
  const adultBlocking = policyEnvelope?.policy.adultBlockingEnabled ?? false;
  const settingsVersion = policyEnvelope?.settingsVersion ?? null;
  const updatedAt = policyEnvelope?.updatedAt ?? null;
  const coverageRows = buildCoverageRows(policyEnvelope, devices);

  return (
    <main className="min-h-[calc(100vh-4rem)] bg-zinc-50">
      <section className="mx-auto flex w-full max-w-6xl flex-col gap-8 px-6 py-12">
        <div className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
          <div className="max-w-2xl">
            <p className="mb-3 text-sm font-medium uppercase tracking-[0.18em] text-zinc-500">
              Account hub
            </p>
            <h1 className="text-4xl font-semibold tracking-tight text-zinc-950 sm:text-5xl">
              Tortoise shows what is desired, installed, and actually live.
            </h1>
            <p className="mt-5 text-lg leading-8 text-zinc-600">
              Supabase policy is the source of truth for desired settings.
              Device health is the source of truth for what the Mac, iPhone,
              and browser extension can enforce right now.
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
              Billing is account-level. TestFlight and early Mac builds use
              beta access until paid plans are turned on.
            </p>
          </section>

          <section className="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm">
            <p className="text-sm font-medium text-zinc-500">Policy sync</p>
            <h2 className="mt-2 text-2xl font-semibold text-zinc-950">
              {!signedIn
                ? "Waiting for sign in"
                : !dataConfigured || syncUnavailable
                  ? "Sync unavailable"
                  : "Current"}
            </h2>
            <p className="mt-3 text-sm leading-6 text-zinc-600">
              {!signedIn
                ? "Sign in to create your shared policy."
                : !dataConfigured
                  ? "Reconnect Supabase server configuration."
                  : syncUnavailable
                    ? "Try again after account services are reachable."
                    : `${policyMode ?? "open"} mode, version ${settingsVersion ?? 0}.`}
            </p>
          </section>
        </div>

        <section>
          <div className="mb-4 flex items-center justify-between gap-4">
            <div>
              <h2 className="text-2xl font-semibold tracking-tight text-zinc-950">
                Downloads and setup
              </h2>
              <p className="mt-1 text-sm text-zinc-600">
                The apps are the primary surfaces. The web dashboard keeps setup
                and recovery clear.
              </p>
            </div>
          </div>
          <div className="grid gap-4 lg:grid-cols-4">
            <SetupLink
              title="Mac"
              description="Desktop policy editing and browser/helper enforcement live here first."
              label="Download Mac"
            />
            <SetupLink
              title="iOS"
              description="Account hub, TestFlight setup, policy sync, and honest iOS capability status."
              label="Install TestFlight"
              href="https://testflight.apple.com/"
            />
            <SetupLink
              title="Chrome"
              description="Connect the extension when browser policy should follow this account."
              label="Connect Chrome"
              href="/extension/connect"
            />
            <SetupLink
              title="Web"
              description="Review account, billing, devices, coverage, and recovery state."
              label="Open dashboard"
              href="/"
            />
          </div>
        </section>

        <section>
          <div className="mb-4 flex items-center justify-between gap-4">
            <div>
              <h2 className="text-2xl font-semibold tracking-tight text-zinc-950">
                Devices
              </h2>
              <p className="mt-1 text-sm text-zinc-600">
                A device is protected only when recent health proves the current
                policy is enforced.
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
                policy={policyEnvelope}
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
                Adult blocking is {adultBlocking ? "on" : "off"}. Local
                Mac/iOS values are cached copies. Health reports can prove
                enforcement, but they never overwrite policy.
              </p>
            </div>
            <dl className="grid min-w-64 gap-4 text-sm sm:grid-cols-2 lg:grid-cols-1">
              <div>
                <dt className="font-medium text-zinc-500">Version</dt>
                <dd className="mt-1 text-zinc-950">
                  {settingsVersion ?? "Unavailable"}
                </dd>
              </div>
              <div>
                <dt className="font-medium text-zinc-500">Last updated</dt>
                <dd className="mt-1 text-zinc-950">{formatDate(updatedAt)}</dd>
              </div>
            </dl>
          </div>
        </section>

        <section className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
          <div>
            <p className="text-sm font-medium text-zinc-500">Protection coverage</p>
            <h2 className="mt-2 text-2xl font-semibold text-zinc-950">
              Policy versus platform reality
            </h2>
            <p className="mt-3 max-w-3xl text-sm leading-6 text-zinc-600">
              This table separates desired account settings from per-device
              capability. It should never imply that iOS is enforcing a Mac or
              browser-only protection.
            </p>
          </div>
          <div className="mt-6 overflow-hidden rounded-lg border border-zinc-200">
            <table className="min-w-full divide-y divide-zinc-200 text-sm">
              <thead className="bg-zinc-50 text-left text-xs font-semibold uppercase tracking-wide text-zinc-500">
                <tr>
                  <th className="px-4 py-3">Protection</th>
                  <th className="px-4 py-3">Policy</th>
                  <th className="px-4 py-3">Mac</th>
                  <th className="px-4 py-3">iPhone/iPad</th>
                  <th className="px-4 py-3">Chrome</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-200 bg-white text-zinc-700">
                {coverageRows.map((row) => (
                  <tr key={row.id}>
                    <td className="px-4 py-3 font-medium text-zinc-950">{row.label}</td>
                    <td className="px-4 py-3">{row.policyState}</td>
                    <td className="px-4 py-3">{row.mac}</td>
                    <td className="px-4 py-3">{row.ios}</td>
                    <td className="px-4 py-3">{row.chrome}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </section>
    </main>
  );
}
