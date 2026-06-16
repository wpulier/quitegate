import { auth } from "@clerk/nextjs/server";
import { hasSupabasePublicConfig } from "@/lib/supabase-clerk";
import { ensureQuietGateAccount } from "@/lib/quietgate-supabase";
import { formatSupabaseError, isClerkSupabaseTokenError } from "@/lib/supabase-errors";

export default async function Home() {
  const { userId } = await auth();
  const supabaseConfigured = hasSupabasePublicConfig();
  let quietGateUserId: string | null = null;
  let policyVersion: number | null = null;
  let policyMode: string | null = null;
  let supabaseError: string | null = null;
  let needsClerkSupabaseSetup = false;

  if (userId && supabaseConfigured) {
    try {
      const account = await ensureQuietGateAccount();
      const user = account.user as { id?: unknown };
      quietGateUserId = typeof user.id === "string" ? user.id : null;
      policyVersion = account.policy.settingsVersion;
      policyMode = account.policy.policy.mode;
    } catch (error) {
      supabaseError = formatSupabaseError(error);
      needsClerkSupabaseSetup = isClerkSupabaseTokenError(supabaseError);
    }
  }

  return (
    <main className="min-h-[calc(100vh-4rem)] bg-zinc-50">
      <section className="mx-auto flex w-full max-w-6xl flex-col gap-10 px-6 py-20">
        <div className="max-w-2xl">
          <p className="mb-3 text-sm font-medium uppercase tracking-[0.18em] text-zinc-500">
            Account sync
          </p>
          <h1 className="text-4xl font-semibold tracking-tight text-zinc-950 sm:text-5xl">
            QuietGate auth is ready for the first test user.
          </h1>
          <p className="mt-5 text-lg leading-8 text-zinc-600">
            Use the navigation buttons to create the first Clerk user. Once
            signed in, this page will confirm the active Clerk user ID.
          </p>
        </div>

        <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
          <p className="text-sm font-medium text-zinc-500">Session status</p>
          <p className="mt-2 text-2xl font-semibold text-zinc-950">
            {userId ? "Signed in" : "Signed out"}
          </p>
          <p className="mt-3 text-sm leading-6 text-zinc-600">
            {userId
              ? `Clerk user ID: ${userId}`
              : "Add your Clerk keys, start the dev server, then sign up through the nav."}
          </p>
        </div>

        <div className="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
          <p className="text-sm font-medium text-zinc-500">Supabase policy DB</p>
          <p className="mt-2 text-2xl font-semibold text-zinc-950">
            {!userId
              ? "Waiting for sign in"
              : !supabaseConfigured
                ? "Waiting for Supabase config"
                : supabaseError
                  ? "Connection needs attention"
                  : "Connected"}
          </p>
          <div className="mt-3 space-y-1 text-sm leading-6 text-zinc-600">
            {!supabaseConfigured ? (
              <p>
                Add Supabase public URL and publishable key to{" "}
                <code className="rounded bg-zinc-100 px-1 py-0.5">
                  .env.local
                </code>{" "}
                to enable policy sync.
              </p>
            ) : supabaseError ? (
              <>
                <p>{supabaseError}</p>
                {needsClerkSupabaseSetup ? (
                  <div className="mt-4 flex flex-wrap gap-3">
                    <a
                      className="rounded-md bg-zinc-950 px-4 py-2 text-sm font-medium text-white"
                      href="https://dashboard.clerk.com/setup/supabase"
                      rel="noreferrer"
                      target="_blank"
                    >
                      Open Clerk setup
                    </a>
                    <a
                      className="rounded-md border border-zinc-300 px-4 py-2 text-sm font-medium text-zinc-900"
                      href="https://supabase.com/dashboard/project/lqfwzuphqkesnoinlvhj/auth/third-party"
                      rel="noreferrer"
                      target="_blank"
                    >
                      Open Supabase provider
                    </a>
                  </div>
                ) : null}
              </>
            ) : quietGateUserId ? (
              <>
                <p>QuietGate user ID: {quietGateUserId}</p>
                <p>
                  Policy: {policyMode} mode, version {policyVersion}
                </p>
              </>
            ) : (
              <p>Sign in to create or load the QuietGate policy record.</p>
            )}
          </div>
        </div>
      </section>
    </main>
  );
}
