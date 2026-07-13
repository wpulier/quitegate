"use client";

import Link from "next/link";
import { SignInButton, SignUpButton, UserButton, useUser } from "@clerk/nextjs";

export function SiteAuthNav() {
  const { isLoaded, isSignedIn } = useUser();

  if (!isLoaded) {
    return <div className="h-9 w-16 rounded-md bg-zinc-100" aria-hidden="true" />;
  }

  return (
    <div className="flex items-center gap-3">
      {isSignedIn ? (
        <>
          <Link
            className="rounded-md px-3 py-2 text-sm font-medium text-zinc-700 transition hover:bg-zinc-100"
            href="/setup"
          >
            Setup
          </Link>
          <UserButton />
        </>
      ) : (
        <>
          <SignInButton fallbackRedirectUrl="/setup" forceRedirectUrl="/setup">
            <button className="rounded-lg px-3 py-2 text-sm font-semibold text-zinc-700 transition hover:bg-zinc-100 focus:outline-none focus:ring-2 focus:ring-[#3e63dd] focus:ring-offset-2">
              Sign in
            </button>
          </SignInButton>
          <SignUpButton fallbackRedirectUrl="/setup" forceRedirectUrl="/setup">
            <button className="rounded-lg bg-[#3e63dd] px-3.5 py-2 text-sm font-semibold text-white transition hover:bg-[#3456c7] focus:outline-none focus:ring-2 focus:ring-[#3e63dd] focus:ring-offset-2">
              Create account
            </button>
          </SignUpButton>
        </>
      )}
    </div>
  );
}
