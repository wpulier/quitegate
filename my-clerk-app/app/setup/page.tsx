import Link from "next/link";
import { SignInButton, SignUpButton } from "@clerk/nextjs";
import { auth, currentUser } from "@clerk/nextjs/server";
import {
  ensureQuietGateAccount,
  hasQuietGateDataConfig,
  listQuietGateDevices,
} from "@/lib/quietgate-supabase";
import type { PolicyEnvelope } from "@/lib/policy-contract";
import type { DashboardDevice } from "@/lib/protection-status";
import {
  deriveSetupSummary,
  setupTone,
  type SetupStepStatus,
} from "@/lib/setup-status";

function StatusBadge({ status }: { status: SetupStepStatus | string }) {
  const label =
    status === "needsAction"
      ? "Needs action"
      : status.charAt(0).toUpperCase() + status.slice(1);

  return (
    <span
      className={`rounded-full px-2.5 py-1 text-xs font-semibold ring-1 ${setupTone(
        status as SetupStepStatus,
      )}`}
    >
      {label}
    </span>
  );
}

export default async function SetupPage() {
  const { userId } = await auth();
  const user = userId ? await currentUser() : null;
  const email = user?.primaryEmailAddress?.emailAddress ?? null;
  const signedIn = Boolean(userId);
  const dataConfigured = hasQuietGateDataConfig();
  let devices: DashboardDevice[] = [];
  let policyEnvelope: PolicyEnvelope | null = null;
  let syncUnavailable = false;

  if (signedIn && dataConfigured) {
    try {
      const account = await ensureQuietGateAccount(email);
      policyEnvelope = account.policy;
      devices = (await listQuietGateDevices()) as DashboardDevice[];
    } catch {
      syncUnavailable = true;
    }
  }

  const setup = deriveSetupSummary({
    signedIn,
    dataConfigured,
    syncUnavailable,
    devices,
    policy: policyEnvelope,
  });

  return (
    <main className="min-h-[calc(100vh-4rem)] bg-zinc-50">
      <section className="mx-auto flex w-full max-w-5xl flex-col gap-8 px-6 py-12">
        <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p className="text-sm font-medium uppercase tracking-[0.18em] text-zinc-500">
              Setup
            </p>
            <h1 className="mt-3 text-4xl font-semibold tracking-tight text-zinc-950">
              Get Tortoise connected.
            </h1>
            <p className="mt-4 max-w-2xl text-sm leading-6 text-zinc-600">
              Finish these items once. Tortoise will keep showing whether Mac,
              iPhone, Safari, and policy sync are actually ready.
            </p>
          </div>
          <div className="rounded-lg border border-zinc-200 bg-white p-4 shadow-sm">
            <div className="flex items-center gap-3">
              <span
                className={`rounded-full px-3 py-1 text-sm font-semibold ring-1 ${setupTone(
                  setup.state,
                )}`}
              >
                {setup.title}
              </span>
              <span className="text-sm font-medium text-zinc-600">
                {setup.completedCount}/{setup.totalCount} complete
              </span>
            </div>
            <p className="mt-3 max-w-md text-sm leading-6 text-zinc-600">
              {setup.detail}
            </p>
          </div>
        </div>

        {!signedIn ? (
          <section className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
            <h2 className="text-2xl font-semibold tracking-tight text-zinc-950">
              Start with an account.
            </h2>
            <p className="mt-3 max-w-2xl text-sm leading-6 text-zinc-600">
              The apps need your Tortoise account before they can share policy,
              device status, and usage summaries.
            </p>
            <div className="mt-5 flex flex-col gap-3 sm:flex-row">
              <SignUpButton fallbackRedirectUrl="/setup" forceRedirectUrl="/setup">
                <button className="rounded-md bg-zinc-950 px-4 py-2 text-sm font-semibold text-white">
                  Create account
                </button>
              </SignUpButton>
              <SignInButton fallbackRedirectUrl="/setup" forceRedirectUrl="/setup">
                <button className="rounded-md border border-zinc-300 bg-white px-4 py-2 text-sm font-semibold text-zinc-900">
                  Sign in
                </button>
              </SignInButton>
            </div>
          </section>
        ) : null}

        <section className="grid gap-4">
          {setup.steps.map((step, index) => (
            <article
              className="rounded-lg border border-zinc-200 bg-white p-5 shadow-sm"
              key={step.id}
            >
              <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                <div className="flex gap-4">
                  <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-zinc-950 text-sm font-bold text-white">
                    {index + 1}
                  </div>
                  <div>
                    <h2 className="text-lg font-semibold text-zinc-950">{step.title}</h2>
                    <p className="mt-2 text-sm leading-6 text-zinc-600">{step.detail}</p>
                  </div>
                </div>
                <div className="flex shrink-0 items-center gap-3 sm:flex-col sm:items-end">
                  <StatusBadge status={step.status} />
                  {step.status === "complete" ? (
                    <span className="text-sm font-semibold text-zinc-500">
                      {step.actionLabel}
                    </span>
                  ) : (
                    <Link
                      className="rounded-md bg-zinc-950 px-3 py-2 text-sm font-semibold text-white transition hover:bg-zinc-800"
                      href={step.href}
                    >
                      {step.actionLabel}
                    </Link>
                  )}
                </div>
              </div>
            </article>
          ))}
        </section>

        <section className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
          <h2 className="text-xl font-semibold tracking-tight text-zinc-950">
            After this checklist
          </h2>
          <p className="mt-3 text-sm leading-6 text-zinc-600">
            Open Tortoise on Mac or iPhone, choose YouTube, and turn on Focus or
            Strict. The dashboard should move from setup status to connected
            status after the apps check in.
          </p>
          <div className="mt-5 flex flex-col gap-3 sm:flex-row">
            <Link
              className="rounded-md border border-zinc-300 bg-white px-4 py-2 text-center text-sm font-semibold text-zinc-900"
              href="/dashboard"
            >
              Open dashboard
            </Link>
            <Link
              className="rounded-md border border-zinc-300 bg-white px-4 py-2 text-center text-sm font-semibold text-zinc-900"
              href="/support"
            >
              Get help
            </Link>
          </div>
        </section>
      </section>
    </main>
  );
}
