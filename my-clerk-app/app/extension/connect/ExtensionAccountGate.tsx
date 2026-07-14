"use client";

import { SignInButton, SignUpButton, useUser } from "@clerk/nextjs";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";

export function ExtensionAccountGate({ returnPath }: { returnPath: string }) {
  const router = useRouter();
  const { isLoaded, isSignedIn } = useUser();
  const refreshStarted = useRef(false);
  const [showRefreshFallback, setShowRefreshFallback] = useState(false);

  useEffect(() => {
    if (!isLoaded || !isSignedIn || refreshStarted.current) {
      return;
    }

    refreshStarted.current = true;
    router.refresh();
    const fallbackTimer = window.setTimeout(() => setShowRefreshFallback(true), 4000);
    return () => window.clearTimeout(fallbackTimer);
  }, [isLoaded, isSignedIn, router]);

  if (!isLoaded || isSignedIn) {
    const finishingConnection = isLoaded && isSignedIn;
    return (
      <section
        aria-live="polite"
        className="w-full rounded-2xl border border-zinc-200 bg-white p-6 shadow-[0_18px_54px_rgba(24,24,27,0.09)] sm:p-8"
      >
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-[#3e63dd]">
          {finishingConnection ? "Account connected" : "Checking account"}
        </p>
        <h2 className="mt-3 text-3xl font-semibold tracking-tight text-zinc-950">
          {finishingConnection ? "Finishing Chrome setup..." : "Getting account status..."}
        </h2>
        <p className="mt-4 text-sm leading-6 text-zinc-600">
          {finishingConnection
            ? "Your Tortoise session is ready. QuietGate is continuing automatically."
            : "QuietGate is securely checking your Tortoise session."}
        </p>
        {showRefreshFallback ? (
          <button
            className="mt-7 min-h-12 w-full rounded-lg bg-[#3e63dd] px-5 text-sm font-semibold text-white transition hover:bg-[#3456c7] focus:outline-none focus:ring-2 focus:ring-[#3e63dd] focus:ring-offset-2"
            type="button"
            onClick={() => window.location.reload()}
          >
            Continue connecting
          </button>
        ) : null}
      </section>
    );
  }

  return (
    <section
      className="w-full rounded-2xl border border-zinc-200 bg-white p-6 shadow-[0_18px_54px_rgba(24,24,27,0.09)] sm:p-8"
      aria-labelledby="connect-account-title"
    >
      <p className="text-xs font-semibold uppercase tracking-[0.16em] text-[#3e63dd]">
        Step 1 of 2
      </p>
      <h2 id="connect-account-title" className="mt-3 text-3xl font-semibold tracking-tight text-zinc-950">
        Start with your account.
      </h2>
      <p className="mt-4 text-sm leading-6 text-zinc-600">
        Use the same Tortoise account as your Mac app. Sign in with Google or
        email and we will bring you back here automatically.
      </p>
      <div className="mt-7 grid gap-3">
        <SignInButton fallbackRedirectUrl={returnPath} forceRedirectUrl={returnPath} mode="modal">
          <button className="min-h-12 rounded-lg bg-[#3e63dd] px-5 text-sm font-semibold text-white transition hover:bg-[#3456c7] focus:outline-none focus:ring-2 focus:ring-[#3e63dd] focus:ring-offset-2" type="button">
            Sign in
          </button>
        </SignInButton>
        <SignUpButton fallbackRedirectUrl={returnPath} forceRedirectUrl={returnPath} mode="modal">
          <button className="min-h-12 rounded-lg border border-zinc-300 bg-white px-5 text-sm font-semibold text-zinc-900 transition hover:border-zinc-400 hover:bg-zinc-50 focus:outline-none focus:ring-2 focus:ring-[#3e63dd] focus:ring-offset-2" type="button">
            Create account
          </button>
        </SignUpButton>
      </div>
      <p className="mt-5 text-xs leading-5 text-zinc-500">
        Authentication is handled securely by Clerk. QuietGate receives only
        the account access needed to sync your settings.
      </p>
    </section>
  );
}
